-- RicksMLC_TreasureHunt.lua
-- Controls a treasure hunt.

-- Each treasure hunt contains one or more treasure maps.  These treasure maps are produced and read in sequence.
-- At any one time there is only one "current" treasure map visible to the player via the Annotated Maps vanilla feature.
-- A treasure map consists of the treasureModData (see CreateTreasureModData()) which is the raw data needed
-- to construct a working Stash and Annotated Map.  The treasureModData is generated from the treasure map definition
-- given by the TreasureHuntMgr.  Some of the attributes are random (such as the selection of the town and building).
-- Therefore, once a treasureModData is intitialised it is stored in the ModData so on subsequent runs of PZ the treasureModData
-- does not change.
--
-- AddStashMap: Stash Maps (which is what Annotated Maps are interinally) must be loaded into the StashSystem at runtime
-- by calling the RicksMLC_TreasureHuntStash.AddStash().
--
-- Reading an Annotated Map works by using the "Map=stashMapName" item and running the function stored in LootMaps.Init[stashMapName]
-- Normally this would be a hard-coded definition of the map boundaries so the UI can display that co-ordinate bounds of the map.  In order
-- to make a general-purpose function which uses the treasureModData to look up the required details for the map it is
-- assigned as LootMaps.Init[stashMapName] = RicksMLC_TreasureHunt.MapDefnFn where stashMapName = GenerateMapName(self.ModData.CurrentMapNum)
-- The MapDefnFn looks up the currently read map and loads the
-- bounds for the map from the lookup.
--
-- Spawning the stash map:  The map is spawned with the followng sequence:
--     local mapItem = InventoryItemFactory.CreateItem("Base.RicksMLC_TreasureMapTemplate")
--     local treasureItem = InventoryItemFactory.CreateItem("Base." .. treasureModData.Treasure)
--     mapItem:setMapID(self:GenerateMapName(self.ModData.CurrentMapNum)) -- Change the ID of the map to the unique ID which matches the LootMap.Init[stashMapName]
--     StashSystem.doStashItem(stash, mapItem)
--     mapItem:setName(mapItem:getDisplayName() .. ": " .. treasureItem:getDisplayName())
--     mapItem:setCustomName(true)
--     return mapItem
--
-- Generate Current Map:
--  The ModData includes two fields: CurrentMapNum and LastSpawnedMapNum
--      CurrentMapNum: The current map to read and find the treasure.
--      LastSpawnedMapNum: The map last spawned on a zombie.
--  The "treasure found" detection is performed in the RicksMLC_TreasureHuntMgr checking each time an item is moved to/from an inventory.
--  If the treasure item is found in the inventory the TresureHunt will look for the next treasure item, and if it is not found it will
--  set the CurrentMapNum to that item, and the Mgr will activate the OnHitZombie() event handler.  When a zombie is hit the Mgr will
--  pass it onto all of the TreasureHunts, and the CurrentMapNum ~= LastSpawnedMapNum it will add the CurrentMapNum to the zombie, and 
--  update the LastSpawnedMapNum to the CurrentMapNum.

local function isTable(o)
    return (type(o) == 'table')
end

require "RicksMLC_TreasureHuntDistributions"
require "RicksMLC_MapUtils"
require "RicksMLC_SharedUtils"
require "StashDescriptions/RicksMLC_StashDescLookup"
require "StashDescriptions/RicksMLC_TreasureHuntStash"
require "ISBaseObject"

LuaEventManager.AddEvent("RicksMLC_TreasureHunt_Finished")

RicksMLC_TreasureHunt = ISBaseObject:derive("RicksMLC_TreasureHunt")
print "RicksMLC_TreasureHunt = ISBaseObject:derive() done"

function RicksMLC_TreasureHunt:new(treasureHuntDefn, huntId)
	local o = {}
	setmetatable(o, self)
	self.__index = self

    o.Name = treasureHuntDefn.Name
    o.Town = treasureHuntDefn.Town -- nil => random
    o.Barricades = treasureHuntDefn.Barricades -- Single number or {min, max}
    o.Zombies = treasureHuntDefn.Zombies -- Single number or {min, max}
    o.Treasures = treasureHuntDefn.Treasures

    o.TreasureHuntDefn = treasureHuntDefn

    -- Treasure lookup
    o.TreasureLookup = {}
    for i, v in ipairs(o.Treasures) do
        if isTable(v) then
            v = v.Item
        end
        o.TreasureLookup[v] = i
    end

    o.HuntId = huntId
    o.MapIDLookup = {}

    o.ModData = nil

    o.Initialised = false
    o.Finished = false
    o.GetMapOnNextZombie = false

    return o
end

-- Persistent Storage: 
-- getGameTime():getModData()["RicksMLC_TreasureHunt"] = {CurrentMapNum = 0, Maps = treasureMaps, Finished = false, LastSpawnedMapNum = 0}

-- SetReadingMap is the external static function called by the override for the Read Map menu item.
local readingMapId = nil
local MapIDLookup = {}
function RicksMLC_TreasureHunt.SetReadingMap(item) readingMapID = item end
function RicksMLC_TreasureHunt:GetReadingMap() return readingMapID end

function RicksMLC_TreasureHunt:GetMapPath(mapNum)
    if not self.ModData.Maps then
        return
    end
    local treasureModData = self.ModData.Maps[mapNum]
    if not treasureModData then return nil end
    return treasureModData.MapPath
end

function RicksMLC_TreasureHunt:setBoundsInSquares(mapAPI, mapNum)
    if not self.ModData.Maps then
        return
    end
    local treasureModData = self.ModData.Maps[self.ModData.CurrentMapNum]
    if mapNum then
        treasureModData = self.ModData.Maps[mapNum]
    end
    local dx = 600
    local dy = 400
    if treasureModData then
        mapAPI:setBoundsInSquares(treasureModData.buildingCentreX - dx, treasureModData.buildingCentreY - dy, treasureModData.buildingCentreX + dx, treasureModData.buildingCentreY + dy)
    end
end

-- Map function for the LootMaps.Init[stashMapName] = RicksMLC_TreasureHunt.MapDefnFn
-- This is part of what ties the map to the stash.
RicksMLC_TreasureHunt.MapDefnFn = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
    local mapPath = RicksMLC_TreasureHuntMgr.Instance():GetMapPath() or 'media/maps/Muldraugh, KY'
	MapUtils.initDirectoryMapData(mapUI, mapPath)
	MapUtils.initDefaultStyleV1(mapUI)
	RicksMLC_MapUtils.ReplaceWaterStyle(mapUI)
	RicksMLC_TreasureHuntMgr.Instance():setBoundsInSquares(mapAPI)
    local currentMapInfo = RicksMLC_TreasureHuntMgr.Instance():FindCurrentlyReadTreasureHunt()
    if currentMapInfo then
        currentMapInfo.TreasureHunt:CallAnyVisualDecorator(currentMapInfo.MapNum, mapUI)
    end
	MapUtils.overlayPaper(mapUI)
end

function RicksMLC_TreasureHunt:CallAnyVisualDecorator(mapNum, mapUI)
    local visualDecoratorName = self.TreasureHuntDefn.VisualDecorator
    if isTable(self.Treasures[mapNum]) and self.Treasures[mapNum].VisualDecorator then
        -- Override the common VisualDecorator with the one defined for this particular treasure item.
        visualDecoratorName = self.Treasures[mapNum].VisualDecorator
    end
    if visualDecoratorName then
        local visualDecorator = RicksMLC_MapDecorators.Instance():Get(visualDecoratorName)
        treasureModData = self.ModData.Maps[mapNum]
        local visualDecoratorData = visualDecorator(mapUI, treasureModData.buildingCentreX, treasureModData.buildingCentreY, treasureModData.VisualDecoratorData)
        if visualDecoratorData then
            self.ModData.Maps[mapNum].VisualDecoratorData = visualDecoratorData
            self:SaveModData()
        end
    end
end

local function calcBuildingCentre(buildingDef)
    return {x = buildingDef:getX() + PZMath.roundToInt(buildingDef:getW() / 2),
            y = buildingDef:getY() + PZMath.roundToInt(buildingDef:getH() / 2)}
end

function RicksMLC_TreasureHunt:IsSameBuilding(treasureModData, buildingDef)
    local buildingCentre = calcBuildingCentre(buildingDef)
    return treasureModData.buildingCentreX == buildingCentre.x and treasureModData.buildingCentreY == buildingCentre.y
end

function RicksMLC_TreasureHunt:IsDuplicateBuilding(nearestBuildingDef)
    local buildingCentre = calcBuildingCentre(nearestBuildingDef)
    --DebugLog.log(DebugType.Mod, "nearestBuildingCentre: x: " .. tostring(buildingCentre.x) .. " y: " .. tostring(buildingCentre.y))
    for i, treasureModData in ipairs(self.ModData.Maps) do
        --DebugLog.log(DebugType.Mod, "   x: " .. tostring(treasureModData.buildingCentreX) .. " y: " .. tostring(treasureDetails.buildingCentreY) )
        if treasureModData.buildingCentreX == buildingCentre.x and treasureModData.buildingCentreY == buildingCentre.y then 
           DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt: isDuplicateBuilding detected. x: " .. tostring(treasureModData.buildingCentreX) .. " y: " .. tostring(treasureModData.buildingCentreY))
           return true
        end
    end
    return false
end

function RicksMLC_TreasureHunt:getNearestBuildingDef(x, y)
    return RicksMLC_MapUtils.getNearestBuildingDef(x, y)
end

-- Choose a random buiding for the treasure.
function RicksMLC_TreasureHunt:ChooseRandomBuilding(mapBounds)
    local x = ZombRand(mapBounds.x1, mapBounds.x2)
    local y = ZombRand(mapBounds.y1, mapBounds.y2)
    local nearestBuildingDef = self:getNearestBuildingDef(x, y)
    local retries = 20
    while ((not nearestBuildingDef or nearestBuildingDef:isHasBeenVisited() or self:IsDuplicateBuilding(nearestBuildingDef)) and retries > 0) do
        x = ZombRand(mapBounds.x1, mapBounds.x2)
        y = ZombRand(mapBounds.y1, mapBounds.y2)
        nearestBuildingDef = self:getNearestBuildingDef(x,  y)
        retries = retries - 1
    end
    
    if not nearestBuildingDef or retries == 0 then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.ChooseRandomBuilding() Error. No buildings within bounds " 
                    .. " x1: " .. tostring(mapBounds.x1) .. " x2: " .. tostring(mapBounds.x2) 
                    .. " y1: " .. tostring(mapBounds.y1) .. " y2: " .. tostring(mapBounds.y2))
        return nil
    end
    return nearestBuildingDef
end

function RicksMLC_TreasureHunt:CreateTreasureModData(treasure, mapBounds)
    local treasureModData = {}
    treasureModData.Building = self:ChooseRandomBuilding(mapBounds)
    if not treasureModData.Building then 
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.CreateTreasureModData ERROR: No building found for mapBounds " .. tostring(mapBounds))
        return nil
    end

    local buildingCentre = calcBuildingCentre(treasureModData.Building)
    treasureModData.buildingCentreX = buildingCentre.x
    treasureModData.buildingCentreY = buildingCentre.y
    treasureModData.MapPath = mapBounds.MapPath
    treasureModData.Treasure = treasure
    local zombieSetting = self.Zombies
    if isTable(treasure) and treasure.Zombies then
        zombieSetting = treasure.Zombies
    end
    if type(zombieSetting) == "table" then
        treasureModData.zombies = ZombRand(zombieSetting[1], zombieSetting[2])
    else
        treasureModData.zombies = zombieSetting
    end

    if RicksMLC_MapUtils.IsNoBarricadeBuilding(treasureModData.buildingCentreX, treasureModData.buildingCentreY) then
        treasureModData.barricades = 0
    else 
        local barricadeSetting = self.Barricades
        if isTable(treasure) and treasure.Barricades then
            barricadeSetting = treasure.Barricades
        end
        if type(barricadeSetting) == "table" then
            treasureModData.barricades = ZombRand(barricadeSetting[1], barricadeSetting[2])
        else
            treasureModData.barricades = barricadeSetting
        end
    end
    treasureModData.Found = false
    return treasureModData
end

 -- This is the name of the map 
function RicksMLC_TreasureHunt:GenerateMapName(i)
    return "RicksMLC_TreasureMap_" .. string.gsub(self.Name, " ", "_") .. "_" .. tostring(i)
end

function RicksMLC_TreasureHunt:CallDecorator(stashMap, treasureModData, i)
    -- Call any Decorator Callback function defined for this treasure item to customise the text and symbols on the map
    local decoratorName = self.TreasureHuntDefn.Decorators and self.TreasureHuntDefn.Decorators[i]
    if not decoratorName then
        decoratorName = self.TreasureHuntDefn.Decorator -- just in case there is a single decorator which is used all treasures.
    end
    if isTable(self.Treasures[i]) and self.Treasures[i].Decorator then
        -- The Item decorator overrides the general decorator list for the hunt.
        decoratorName = self.Treasures[i].Decorator
    end
    if decoratorName then
        local decorator = RicksMLC_MapDecorators.Instance():Get(decoratorName)
        decorator(stashMap, treasureModData.buildingCentreX, treasureModData.buildingCentreY)
    else
        RicksMLC_TreasureHuntStash.DefaultDecorator(stashMap, treasureModData.buildingCentreX, treasureModData.buildingCentreY)
    end
end

local function dumpStash(stashMap)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntStash.AddStash() spawnTable " .. stashMap.spawnTable)
    local dist = SuburbsDistributions

    local tmpTable = dist[stashMap.spawnTable]
    if tmpTable then
        RicksMLC_THSharedUtils.DumpArgs(tmpTable, 0, "SuburbsDistributions stashMap.spawnTable")
    end
    local tmpProcTable = ProceduralDistributions.list[stashMap.spawnTable .. "Proc"]
    if tmpProcTable then
        RicksMLC_THSharedUtils.DumpArgs(tmpProcTable, 0, "stashMap.spawnTable .. Proc")
    end
end

function RicksMLC_TreasureHunt:AddStashToStashUtil(treasureModData, i, stashMapName)
    local spawnTable = stashMapName -- This string is the lookup into the SuburbsDisributions table.  See RicksMLC_TreasureHuntDistributions.lua
    local newStashMap = RicksMLC_TreasureHuntStash.AddStash(
        stashMapName,
        treasureModData.buildingCentreX,
        treasureModData.buildingCentreY, 
        treasureModData.barricades,
        treasureModData.zombies,
        "Base." .. stashMapName,
        spawnTable)
    
        dumpStash(newStashMap)        

    self:CallDecorator(newStashMap, treasureModData, i)
    RicksMLC_StashDescLookup.Instance():AddNewStash(stashMapName)
end

function RicksMLC_TreasureHunt:AddStashMap(treasureModData, i)
    local stashMapName = self:GenerateMapName(i)
    local stashDesc = RicksMLC_StashDescLookup.Instance():StashLookup(stashMapName)
    if not stashDesc then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt:AddStashMap() Adding stash for " .. stashMapName)
        self:AddStashToStashUtil(treasureModData, i, stashMapName)
        -- local spawnTable = stashMapName -- This string is the lookup into the SuburbsDisributions table.  See RicksMLC_TreasureHuntDistributions.lua
        -- local newStashMap = RicksMLC_TreasureHuntStash.AddStash(
        --     stashMapName,
        --     treasureModData.buildingCentreX,
        --     treasureModData.buildingCentreY, 
        --     treasureModData.barricades,
        --     treasureModData.zombies,
        --     "Base." .. stashMapName,
        --     spawnTable)
        
        --     dumpStash(newStashMap)        

        -- self:CallDecorator(newStashMap, treasureModData, i)
        -- RicksMLC_StashDescLookup.Instance():AddNewStash(stashMapName)
    else
        DebugLog.log(DebugType.Mod, "  Found existing stash for " .. stashMapName)
        RicksMLC_THSharedUtils.DumpArgs(stashDesc, 0, "Existing Stash Details")
    end
    if isClient() or not isServer() then
        LootMaps.Init[stashMapName] = RicksMLC_TreasureHunt.MapDefnFn
    end
    RicksMLC_MapIDLookup.Instance():AddMapID(stashMapName, self.HuntId, i)
end

function RicksMLC_TreasureHunt:AddStashMaps()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.AddStashMaps()")
    --FIXME: Remove
    -- local stashLookup = {}
    -- for i, stashDesc in ipairs(StashDescriptions) do
    --     stashLookup[stashDesc.name] = stashDesc
    -- end
    for i, treasureModData in ipairs(self.ModData.Maps) do
        -- Check if the stash already exists
        self:AddStashMap(treasureModData, i)
    end
end

-- GenerateTreasure(treasure,i) Generate the given treasure into the i'th position.
-- Generate means:
--      Choose a random town if none specified
--      CreateTreasureModData() Chooses the building and sets the zombies, barricades
-- The generated map is stored in the i'th postition in the self.ModData.Maps
function RicksMLC_TreasureHunt:GenerateTreasure(treasure, i, optionalTown, optionalMapNum)
    if self.ModData.Maps[i] then
        if not self.ModData.Maps[i].Building then
            -- The ModData will not store the BuildingDef so populate it using the building co-ords
            self.ModData.Maps[i].Building = self:getNearestBuildingDef(self.ModData.Maps[i].buildingCentreX, self.ModData.Maps[i].buildingCentreY)
        end
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt:GenerateTreasure() treasure: " .. ((isTable(treasure) and treasure.Item) or treasure) .. " " .. self.ModData.Maps[i].Town.Town)
        RicksMLC_THSharedUtils.DumpArgs(self.ModData.Maps[i], 0, "Existing treasureModData")
    else
        local town = nil
        if optionalTown then
            town = {Town = optionalTown, MapNum = optionalMapNum}
            if optionalTown == "Louisville" and not optionalMapNum then
                town.MapNum = ZombRand(1, 9)
            end
        else
            town = RicksMLC_MapUtils.GetRandomTown()
        end
        local mapBounds = RicksMLC_MapUtils.GetMapExtents(town.Town, town.MapNum)
        if not mapBounds then
            DebugLog.log(DebugType.Mod, "ERROR: RicksMLC_TreasureHunt:GenerateTreasure() No map extents found for Town: '" .. town.Town .. "' MapNum: " .. tostring(town.MapNum) .. " No Treasure Map Generated.")
            return
        end
        self.ModData.Maps[i] = self:CreateTreasureModData(treasure, mapBounds)
        if not self.ModData.Maps[i] then return end -- If no building could be found abort.
        self.ModData.Maps[i].Town = town
        self:SaveModData()
        DebugLog.log(DebugType.Mod, "    New treasure: "  .. ((isTable(treasure) and treasure.Item) or treasure) .. " " .. self.ModData.Maps[i].Town.Town)
    end
end

function RicksMLC_TreasureHunt:GeneratePastTreasures()
    -- Assemble the treasure data for all treasures maps that have been made.
    for i, treasureModData in ipairs(self.ModData.Maps) do
        self:GenerateTreasure(self.Treasures[i], i, treasureModData.Town.Town, treasureModData.Town.MapNum)
        if not self.ModData.Maps[i] then
            -- The GenerateTreasure failed
            self:FinishHunt(true)
        end
        -- Ensure the stash distrubutions are included before generating the stashMaps, otherwise on restart the stash buildings will be empty.
        if not RicksMLC_TreasureHuntDistributions.Instance():IsInDistribution(self:GenerateMapName(i)) then
            RicksMLC_TreasureHuntDistributions.Instance():AddSingleTreasureToDistribution(self.Treasures[i], self:GenerateMapName(i))
        end
        -- FIXME: Temp workaround for missing stashMap data not stored in the ModData (experimental)
        if not treasureModData.stashMapName then
            DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt:GeneratePastTreasures() missing stashMapName '".. treasureModData.stashMapName .. "'  Restoring")
            treasureModData.stashMapName = self:GenerateMapName(i)
        end
        if isClient() or not isServer() then
            if not LootMaps.Init[treasureModData.stashMapName] then
                DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt:GeneratePastTreasures() missing LootMaps.Init[".. treasureModData.stashMapName .. "].  Restoring")
                LootMaps.Init[treasureModData.stashMapName] = RicksMLC_TreasureHunt.MapDefnFn
            end
        end
        local mapLookup = RicksMLC_MapIDLookup.Instance():GetMapLookup(treasureModData.stashMapName)
        if not mapLookup then
            DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt:GeneratePastTreasures() missing RicksMLC_MapIDLookup('".. treasureModData.stashMapName .."').  Restoring")
            RicksMLC_MapIDLookup.Instance():AddMapID(treasureModData.stashMapName, self.HuntId, i)
        end
    end
end

function RicksMLC_TreasureHunt:LoadModData()
    local modData = getGameTime():getModData()["RicksMLC_TreasureHunt"]
    if not modData then
        -- This is the first time any treasure hunts have been loaded
        getGameTime():getModData()["RicksMLC_TreasureHunt"] = {}
    end
    self.ModData = getGameTime():getModData()["RicksMLC_TreasureHunt"][self.Name]
    if not self.ModData then
        self.ModData = {CurrentMapNum = 0, Maps = {}, Finished = false, LastSpawnedMapNum = 0, 
                        Statistics = {Start = nil, End = nil, Kills = nil, Deaths = nil}}
    end
end

function RicksMLC_TreasureHunt:SaveModData()
    if not getGameTime():getModData()["RicksMLC_TreasureHunt"] then
        getGameTime():getModData()["RicksMLC_TreasureHunt"] = {}    
    end
    getGameTime():getModData()["RicksMLC_TreasureHunt"][self.Name] = self.ModData
end

-- treasure could be a single string: simple case
-- or a table, which means the treasure is a fine-grained treasure definition.
-- Adding a new treasure hunt means:
--      GenerateTreasure() choose the town and building and set the treasure defn for the vanilla Stash system (barricades, zombies)
--      AddStashMap() Create the Stash map for the generated details to the vanilla stash system.
function RicksMLC_TreasureHunt:AddNewTreasureToHunt(treasure, townName)
    local i = #self.ModData.Maps + 1
    local mapNum = nil
    if isTable(treasure) then
        -- This is a fine-grained treasure item definition
        if treasure.Town then
            -- Override the town
            if isTable(treasure.Town) then
                townName = treasure.Town.Town
                if treasure.Town.MapNum then
                    mapNum = treasure.Town.MapNum
                end
            else
                townName = treasure.Town
            end
        end
    end
    self:GenerateTreasure(treasure, i, townName, mapNum)
    -- The self.ModData.Maps[i] now contains the treasure data for the new map or null if aborted
    if not self.ModData.Maps[i] then
        DebugLog.log(DebugType.Mod, "ERROR: RicksMLC_TreasureHunt:AddNewTreasureToHunt() Unable to generate treasure map.")
        self:FinishHunt(true)
        return
    end
    if not RicksMLC_TreasureHuntDistributions.Instance():IsInDistribution(self:GenerateMapName(i)) then
        RicksMLC_TreasureHuntDistributions.Instance():AddSingleTreasureToDistribution(treasure, self:GenerateMapName(i))
    end
    self:AddStashMap(self.ModData.Maps[i], i)
end

function RicksMLC_TreasureHunt:FinishHunt(bError)
    self.ModData.Finished = true
    self:SaveModData()
    if bError then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt:FinishHunt() Finished in ERROR state - something went wrong.")
        return
    end
    triggerEvent("RicksMLC_TreasureHunt_Finished", self.TreasureHuntDefn)
end

function RicksMLC_TreasureHunt:GenerateNextTreasureMap()
    local i = #self.ModData.Maps + 1
    if not self.Treasures[i] and not self.ModData.Finished then
        self:FinishHunt()
        return
    end
    self:AddNewTreasureToHunt(self.Treasures[i], self.Town)
    -- The StashSystem.reinit() is necessary when adding a stash after the game is started.
    -- If the StashSystem is not reinitialised the StashSystem.getStash() not find the stash, even if the
    -- stash name is in the StashSystem.getPossibleStashes():get(i):getName()
    StashSystem.reinit()
end

-- InitTreasureHunt() 
-- Load the stored data for any existing hunt.
-- Generate the past treasure data so any old maps can still be read.
-- Initialise the stash maps that correspond with the treasure data.
function RicksMLC_TreasureHunt:InitTreasureHunt()
    self:LoadModData()
    self:GeneratePastTreasures()
    if not self.ModData.Maps then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.InitTreasureHunt() ERROR: Failed to Generate treasures")
        return
    end
    self:SaveModData()
    self.Initialised = true
    RicksMLC_THSharedUtils.DumpArgs(self.ModData, 0, "InitTreasureHunt post GeneratePastTreasures")
    self:AddStashMaps()
    -- The reinit is necessary when adding a stash after the game is started.
    -- If the StashSystem is not reinitialised the StashSystem.getStash() not find the stash, even if the
    -- stash name is in the StashSystem.getPossibleStashes():get(i):getName()
    StashSystem.reinit()
end

-----------------------------------------------------------------------
-- Functions for detecting the player found the treasure item.

function RicksMLC_TreasureHunt:GenerateNextMapItem(doStash)
    if not self.ModData.Maps then 
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.GenerateNextMapItem() Error: no treasureHunt data for player")
        return
    end

    local treasureModData = self.ModData.Maps[self.ModData.CurrentMapNum]
    local stash = StashSystem.getStash(self:GenerateMapName(self.ModData.CurrentMapNum))
    if not stash then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.GenerateNextMapItem() Error: no stash for '" .. self:GenerateMapName(self.ModData.CurrentMapNum) .. "'" )
        return
    end
    local mapItem = InventoryItemFactory.CreateItem("Base.RicksMLC_TreasureMapTemplate")
    mapItem:setMapID(self:GenerateMapName(self.ModData.CurrentMapNum))
    if doStash then
        StashSystem.doStashItem(stash, mapItem) -- Copies the stash.annotations to the java layer stash object and removes from potential stashes.
        mapItem:doBuildingStash()
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt:GenerateNextMapItem(): doStashItem() called for '" .. mapItem:getMapID() .. "'")
    else
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt:GenerateNextMapItem(): no doStashItem() called for '" .. mapItem:getMapID() .. "'")
    end
    mapItem:setName(mapItem:getDisplayName() .. ": " .. self.Name .. " [" .. tostring(self.ModData.CurrentMapNum) .. "]")-- treasureItem:getDisplayName())
    mapItem:setCustomName(true)
    return mapItem
end

function RicksMLC_TreasureHunt:IsBuildingVisited()
    local treasureModData = self.ModData.Maps[self.ModData.CurrentMapNum]
    local buildingDef = treasureModData.Building
    if not buildingDef then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt:IsBuildingVisited() No Building def assigned")
    end
end

function RicksMLC_TreasureHunt:AddNextMapToZombie(zombie, doStash)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.AddNextMapToZombie()")
    if not self.ModData.Maps[self.ModData.CurrentMapNum] or self.ModData.Maps[self.ModData.CurrentMapNum].Found then
        self:GenerateNextTreasureMap()
        if self.ModData.Finished then
            DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt:AddNextMapToZombie() Generated map failed. FINISHED - Aborting AddNextMapToZombie()")
            return
        end
    end
    local mapItem = self:GenerateNextMapItem(doStash)
    self.ModData.Maps[self.ModData.CurrentMapNum].stashMapName = mapItem:getMapID()
    self.ModData.Maps[self.ModData.CurrentMapNum].mapDisplayName = mapItem:getDisplayName()
    if zombie then
        -- This may be called in the server, where the zombie is not defined
        zombie:addItemToSpawnAtDeath(mapItem)
    end
    -- Check if the building has been visited before now.
    if self:IsBuildingVisited() then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt:AddNextMapToZombie(): WARNING Buiding already visited for map " .. mapItem:getName())
        return nil
    end
    self:SaveModData()
    local mapItemDetails = {
        mapItem = mapItem,
        stashMapName = mapItem:getMapID(), 
        huntId = self.HuntId, 
        i = self.ModData.CurrentMapNum, 
        Name = self.Name,
        displayName = mapItem:getDisplayName(),
        treasureModData = self.ModData.Maps[self.ModData.CurrentMapNum],
        Maps = self.ModData.Maps
    } 
    RicksMLC_THSharedUtils.DumpArgs(mapItemDetails, 0, "RicksMLC_TreasureHunt:AddNextMapToZombie() return:")
    return mapItemDetails
end

function RicksMLC_TreasureHunt:GetCurrentTreasureHuntInfo()
    local modData = self.ModData.Maps[self.ModData.CurrentMapNum]
    return {
        name = self.Name,
        huntId = self.HuntId, 
        i = self.ModData.CurrentMapNum, 
        lastSpawnedMapNum = self.ModData.LastSpawnedMapNum,
        isNewMapNeeded = self:IsNewMapNeeded(),
        finished = self.ModData.Finished,
        treasureHuntDefn = self.TreasureHuntDefn,
        treasureModData = modData,
        modData = self.ModData}
end

function RicksMLC_TreasureHunt:Dump()
    RicksMLC_THSharedUtils.DumpArgs(self.ModData, 0, "RicksMLC_TreasureHunt")

    if self.ModData.Maps[self.ModData.CurrentMapNum] then
        local map = self.ModData.Maps[self.ModData.CurrentMapNum]
        local closestXY = Vector2f:new(1000, 1000)
        local nearestBuildingDef = AmbientStreamManager.instance:getNearestBuilding(map.buildingCentreX,  map.buildingCentreY, closestXY)
        if nearestBuildingDef then
            RicksMLC_StashUtils.Dump(nearestBuildingDef, ((isTable(treasureModData.Treasure) and Treasure.Item) or treasure), map.buildingCentreX,  map.buildingCentreY)
        end
    end
end

function RicksMLC_TreasureHunt.IsTreasureHuntItem(x, obj)
    return x:getType() == obj.Treasures[obj.ModData.CurrentMapNum]
       and x:getModData()["RicksMLC_Treasure"] == obj:GenerateMapName(self.ModData.CurrentMapNum)
end

function RicksMLC_TreasureHunt:FoundMissingTreasureItem(itemContainer)
    local itemList = ArrayList:new()
    itemContainer:getAllEvalArgRecurse(RicksMLC_TreasureHunt.IsTreasureHuntItem, self, itemList)
    if not itemList:isEmpty() then
        item = itemList:get(0):getType()
        -- not found, so return it as the next thing to find
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.FindMissingTreasureItem() found treasure " .. tostring(self.ModData.CurrentMapNum) .. " '" .. item:getType() .. "'")
        return {TreasureNum = obj.ModData.CurrentMapNum, Treasure = item:getType()}
    end
    return nil
end

local function matchAnyTreasureClosure(x, obj)
    if x:getModData()["RicksMLC_Treasure"] == "Not a treasure item" then return false end
    --DebugLog.log(DebugType.Mod, "matchAnyTreasureClosure() x: type: '" .. x:getType() .. "', fullType: '" .. x:getFullType() .. "'")
    local matchItem = obj.TreasureLookup[x:getType()] or obj.TreasureLookup[x:getFullType()]
    if matchItem then
        return true
    end
    return false
end

function RicksMLC_TreasureHunt:FinishOrSetNextMap()
    self.ModData.Maps[self.ModData.CurrentMapNum].Found = true
    if self.ModData.CurrentMapNum == #self.Treasures then
        self:FinishHunt()
    else
        self.ModData.CurrentMapNum = self.ModData.CurrentMapNum + 1
    end
    self:SaveModData()
end

function RicksMLC_TreasureHunt:RecordFoundTreasure(item)
    local foundMapNum = self.ModData.CurrentMapNum
    -- Record the item as a found treasure item so it can't be used again.
    item:getModData()["RicksMLC_Treasure"] = self:GenerateMapName(self.ModData.CurrentMapNum)
    self:FinishOrSetNextMap()
    RicksMLC_TreasureHuntMgr.Instance():RecordFoundTreasure(self.HuntId, foundMapNum)
end

function RicksMLC_TreasureHunt:IsNewMapNeeded()
    return not self.Finished and (self.ModData.CurrentMapNum == 0 or self.ModData.CurrentMapNum > self.ModData.LastSpawnedMapNum)
end

function RicksMLC_TreasureHunt:CheckIfNewMapNeeded(player)
    if self.ModData.Finished then return {UnassignedItems = {}, NewMapNeeded = false} end

    local possibleTreasureItems = {}
    -- Check if the current treasure has been added to the player inventory
    if self.ModData.CurrentMapNum == 0 then
        self.ModData.CurrentMapNum = 1
        self:SaveModData()
    else
        local treasureModData = self.ModData.Maps[self.ModData.CurrentMapNum]
        local itemContainer = player:getInventory()
        local itemList = itemContainer:getAllEvalArgRecurse(matchAnyTreasureClosure, self)
        if not itemList:isEmpty() then
            for i = 0, itemList:size()-1 do 
                local item = itemList:get(i)
                local currentBuildingDef = player:getCurrentBuildingDef()
                if currentBuildingDef and treasureModData and self:IsSameBuilding(treasureModData, currentBuildingDef) then
                    if not item:getModData()["RicksMLC_Treasure"] then 
                        -- This is the first time the item has been seen and this is the correct place
                        self:RecordFoundTreasure(item)
                    else
                        local itemModData = item:getModData()["RicksMLC_Treasure"]
                        if itemModData == "Possible Treasure Item" then
                            -- This item has been recorded as "possible" in another treasure hunt, so this is it.
                            -- Assign this treasure to the current map
                            self:RecordFoundTreasure(item)
                        end
                    end
                else
                    -- This item is not a real treasure item.
                    local itemModData = item:getModData()["RicksMLC_Treasure"]
                    if not itemModData then
                        item:getModData()["RicksMLC_Treasure"] = "Possible Treasure Item"
                        possibleTreasureItems[#possibleTreasureItems+1] = item
                    end
                end
            end
        end
    end

    return {UnassignedItems = possibleTreasureItems, NewMapNeeded = self.ModData.CurrentMapNum > self.ModData.LastSpawnedMapNum}
end

function RicksMLC_TreasureHunt:ResetLastSpawnedMapNum()
    if self.ModData.Maps[self.ModData.CurrentMapNum] and not self.ModData.Finished and not self.ModData.Maps[self.ModData.CurrentMapNum].Found and self.ModData.CurrentMapNum > 0 then
        self.ModData.LastSpawnedMapNum = self.ModData.CurrentMapNum - 1
    end
end

-- FIXME: This is a workaround which may have to remain for the server side.
function RicksMLC_TreasureHunt:HandleClientOnHitZombie(player, character)
    -- Server side handling of a client hitting a zombie - generate the treasure map defn (distribtions etc)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.HandleClientOnHitZombie() ".. self.Name)
    if self.ModData.Finished then return nil end
    local mapItemDetails = nil
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.HandleClientOnHitZombie() CurrentMapNum: " .. tostring(self.ModData.CurrentMapNum) .. " LastSpawnedMapNum " .. tostring(self.ModData.LastSpawnedMapNum))
--    if self.ModData.CurrentMapNum == 0 then
        -- FIXME: Should this really be incrementing as this is generating a new map anyway.
        self.ModData.CurrentMapNum = self.ModData.CurrentMapNum + 1
--    end
    if self.ModData.CurrentMapNum ~= self.ModData.LastSpawnedMapNum then
        mapItemDetails = self:AddNextMapToZombie(nil, true)

        self.ModData.LastSpawnedMapNum = self.ModData.CurrentMapNum
        self:SaveModData()
    end
    return mapItemDetails
end

-- function RicksMLC_TreasureHunt:HandleOnHitZombieNoStash(zombie, character, bodyPartType, handWeapon)
--     DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.HandleOnHitZombie()")
--     if self.ModData.Finished then return false end
--     -- Make sure it's not just any character that hits the zombie
--     local mapItem = nil
--     if character == getPlayer() and self.ModData.CurrentMapNum ~= self.ModData.LastSpawnedMapNum then
--         mapItemDetails = self:AddNextMapToZombie(zombie, false)
--         self.ModData.LastSpawnedMapNum = self.ModData.CurrentMapNum
--         self:SaveModData()
--     end
--     return mapItemDetails 
-- end


function RicksMLC_TreasureHunt:HandleOnHitZombie(zombie, character, bodyPartType, handWeapon, doStash)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.HandleOnHitZombie()")
    if self.ModData.Finished then return false end
    -- Make sure it's not just any character that hits the zombie
    local mapItem = nil
    if character == getPlayer() and self.ModData.CurrentMapNum ~= self.ModData.LastSpawnedMapNum then
        mapItemDetails = self:AddNextMapToZombie(zombie, doStash)
        self.ModData.LastSpawnedMapNum = self.ModData.CurrentMapNum
        self:SaveModData()
    end
    return mapItemDetails
end

---------------------------------------------
-- Static methods

