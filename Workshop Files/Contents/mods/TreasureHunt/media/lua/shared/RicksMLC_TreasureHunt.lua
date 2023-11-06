-- RicksMLC_TreasureHunt.lua
-- Controls a treasure hunt.

-- Each treasure hunt contains one or more treasure maps.  These treasure maps are produced and read in sequence.
-- At any one time there is only one "current" treasure map visible to the player via the Annotated Maps vanilla feature.
-- A treasure map consists of the TreasureData (see CreateTreasureData()) which is the raw data needed
-- to construct a working Stash and Annotated Map.  The TreasureData is generated from the treasure map definition
-- given by the TreasureHuntMgr.  Some of the attributes are random (such as the selection of the town and building).
-- Therefore, once a TreasureData is intitialised it is stored in the ModData so on subsequent runs of PZ the TreasureData
-- does not change.
--
-- AddStashMap: Stash Maps (which is what Annotated Maps are interinally) must be loaded into the StashSystem at runtime
-- by calling the RicksMLC_TreasureHuntStash.AddStash().
--
-- Reading an Annotated Map works by using the "Map=stashMapName" item and running the function stored in LootMaps.Init[stashMapName]
-- Normally this would be a hard-coded definition of the map boundaries so the UI can display that co-ordinate bounds of the map.  In order
-- to make a general-purpose function which uses the TreasureData to look up the required details for the map it is
-- assigned as LootMaps.Init[stashMapName] = RicksMLC_TreasureHunt.MapDefnFn where stashMapName = GenerateMapName(self.ModData.CurrentMapNum)
-- The MapDefnFn looks up the currently read map and loads the
-- bounds for the map from the lookup.
--
-- Spawning the stash map:  The map is spawned with the followng sequence:
--     local mapItem = InventoryItemFactory.CreateItem("Base.RicksMLC_TreasureMapTemplate")
--     local treasureItem = InventoryItemFactory.CreateItem("Base." .. treasureData.Treasure)
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

require "StashDescriptions/RicksMLC_TreasureHuntStash"
require "RicksMLC_MapUtils"
require "RicksMLC_SharedUtils"
require "RicksMLC_StashDescLookup"
require "ISBaseObject"

LuaEventManager.AddEvent("RicksMLC_TreasureHunt_Finished")

RicksMLC_TreasureHunt = ISBaseObject:derive("RicksMLC_TreasureHunt");

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
    local treasureData = self.ModData.Maps[mapNum]
    if not treasureData then return nil end
    return treasureData.MapPath
end

function RicksMLC_TreasureHunt:setBoundsInSquares(mapAPI, mapNum)
    if not self.ModData.Maps then
        return
    end
    local treasureData = self.ModData.Maps[self.ModData.CurrentMapNum]
    if mapNum then
        treasureData = self.ModData.Maps[mapNum]
    end
    local dx = 600
    local dy = 400
    if treasureData then
        mapAPI:setBoundsInSquares(treasureData.buildingCentreX - dx, treasureData.buildingCentreY - dy, treasureData.buildingCentreX + dx, treasureData.buildingCentreY + dy)
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
	MapUtils.overlayPaper(mapUI)
end

local function calcBuildingCentre(buildingDef)
    return {x = buildingDef:getX() + PZMath.roundToInt(buildingDef:getW() / 2),
            y = buildingDef:getY() + PZMath.roundToInt(buildingDef:getH() / 2)}
end

function RicksMLC_TreasureHunt:IsSameBuilding(treasureData, buildingDef)
    local buildingCentre = calcBuildingCentre(buildingDef)
    return treasureData.buildingCentreX == buildingCentre.x and treasureData.buildingCentreY == buildingCentre.y
end

function RicksMLC_TreasureHunt:IsDuplicateBuilding(nearestBuildingDef)
    local buildingCentre = calcBuildingCentre(nearestBuildingDef)
    --DebugLog.log(DebugType.Mod, "nearestBuildingCentre: x: " .. tostring(buildingCentre.x) .. " y: " .. tostring(buildingCentre.y))
    for i, treasureData in ipairs(self.ModData.Maps) do
        --DebugLog.log(DebugType.Mod, "   x: " .. tostring(treasureData.buildingCentreX) .. " y: " .. tostring(treasureDetails.buildingCentreY) )
        if treasureData.buildingCentreX == buildingCentre.x and treasureData.buildingCentreY == buildingCentre.y then 
           DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt: isDuplicateBuilding detected. x: " .. tostring(treasureData.buildingCentreX) .. " y: " .. tostring(treasureData.buildingCentreY))
           return true
        end
    end
    return false
end

function RicksMLC_TreasureHunt:getNearestBuildingDef(x, y)
    local closestXY = Vector2f:new(1000, 1000)
    return AmbientStreamManager.instance:getNearestBuilding(x,  y, closestXY)
end

-- Choose a random buiding for the treasure.
function RicksMLC_TreasureHunt:ChooseRandomBuilding(mapBounds)
    local x = ZombRand(mapBounds.x1, mapBounds.x2)
    local y = ZombRand(mapBounds.y1, mapBounds.y2)
    local nearestBuildingDef = self:getNearestBuildingDef(x, y)
    local retries = 20
    while (not nearestBuildingDef or nearestBuildingDef:isHasBeenVisited() or self:IsDuplicateBuilding(nearestBuildingDef) and retries > 0) do
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

function RicksMLC_TreasureHunt:CreateTreasureData(treasure, mapBounds)
    local treasureData = {}
    treasureData.Building = self:ChooseRandomBuilding(mapBounds)
    if not treasureData.Building then 
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.CreateTreasureData ERROR: No building found for mapBounds " .. tostring(mapBounds))
        return nil
    end

    local buildingCentre = calcBuildingCentre(treasureData.Building)
    treasureData.buildingCentreX = buildingCentre.x
    treasureData.buildingCentreY = buildingCentre.y
    treasureData.MapPath = mapBounds.MapPath
    treasureData.Treasure = treasure
    if type(self.Zombies) == "table" then
        treasureData.zombies = ZombRand(self.Zombies[1], self.Zombies[2])
    else
        treasureData.zombies = self.Zombies
    end

    if RicksMLC_MapUtils.IsNoBarricadeBuilding(treasureData.buildingCentreX, treasureData.buildingCentreY) then
        treasureData.barricades = 0
    else 
        if type(self.Barricades) == "table" then
            treasureData.barricades = ZombRand(self.Barricades[1], self.Barricades[2])
        else
            treasureData.barricades = self.Barricades
        end
    end
    return treasureData
end

 -- This is the name of the map item 
function RicksMLC_TreasureHunt:GenerateMapName(i)
    return "RicksMLC_TreasureMap_" .. self.Name .. "_" .. tostring(i)
end

function RicksMLC_TreasureHunt:AddStashMap(treasureData, i, stashLookup)
    local stashMapName = self:GenerateMapName(i)
    -- FIXME: Should the StashDescLookup re-populate the lookup each time so new maps are included?
    local stashDesc = RicksMLC_StashDescLookup.Instance():StashLookup(stashMapName)
    if not stashDesc then
        DebugLog.log(DebugType.Mod, "   Adding stash for " .. treasureData.Treasure)
        local spawnTable = "RicksMLC_" .. treasureData.Treasure -- This string is the lookup into the SuburbsDisributions table.  See RicksMLC_TreasureHuntDistributions.lua
        local newStashMap = RicksMLC_TreasureHuntStash.AddStash(
            stashMapName,
            treasureData.buildingCentreX,
            treasureData.buildingCentreY, 
            treasureData.barricades,
            treasureData.zombies,
            "Base." .. stashMapName,
            spawnTable)

        -- TODO: Change this to a DecoratorCallback function so the treasureHuntDefn can customise the text and symbols on the map
        newStashMap:addStamp(nil, self.Name .. ": " .. treasureData.Treasure, treasureData.buildingCentreX-100, treasureData.buildingCentreY - 100, 0, 0, 1) -- symbol,text,mapX,mapY,r,g,b
    else
        DebugLog.log(DebugType.Mod, "  Found existing stash for " .. treasureData.Treasure)
        RicksMLC_THSharedUtils.DumpArgs(stashDesc, 0, "Existing Stash Details")
    end
    LootMaps.Init[stashMapName] = RicksMLC_TreasureHunt.MapDefnFn
    RicksMLC_MapIDLookup.Instance():AddMapID(self:GenerateMapName(i), self.HuntId, i)
end

function RicksMLC_TreasureHunt:AddStashMaps()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.AddStashMaps()")
    local stashLookup = {}
    for i, stashDesc in ipairs(StashDescriptions) do
        stashLookup[stashDesc.name] = stashDesc
    end
    for i, treasureData in ipairs(self.ModData.Maps) do
        -- Check if the stash already exists
        self:AddStashMap(treasureData, i, stashLookup)
    end
end

-- GenerateTreasure(treasure,i) Generate the given treasure into the i'th position.
-- The generated map is stored in the i'th postition in the self.ModData.Maps
function RicksMLC_TreasureHunt:GenerateTreasure(treasure, i, optionalTown, optionalMapNum)
    if self.ModData.Maps[i] then
        if not self.ModData.Maps[i].Building then
            -- The ModData will not store the BuildingDef so populate it using the building co-ords
            self.ModData.Maps[i].Building = self:getNearestBuildingDef(self.ModData.Maps[i].buildingCentreX, self.ModData.Maps[i].buildingCentreY)
        end
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt:GenerateTreasure() treasure: " .. treasure .. " " .. self.ModData.Maps[i].Town.Town)
        RicksMLC_THSharedUtils.DumpArgs(self.ModData.Maps[i], 0, "Existing treasureData")
    else
        local town = nil
        if optionalTown then
            town = {Town = optionalTown, MapNum = optionalMapNum}
        else
            town = RicksMLC_MapUtils.GetRandomTown()
        end
        local mapBounds = RicksMLC_MapUtils.GetMapExtents(town.Town, town.MapNum)
        self.ModData.Maps[i] = self:CreateTreasureData(treasure, mapBounds)
        if not self.ModData.Maps[i] then return end -- If no building could be found abort.
        self.ModData.Maps[i].Town = town
        self:SaveModData()
        --DebugLog.log(DebugType.Mod, "    New treasure: "  .. treasure .. " " .. self.ModData.Maps[i].Town.Town)
    end
end

function RicksMLC_TreasureHunt:GeneratePastTreasures()
    -- Assemble the treasure data for all treasures maps that have been made.
    for i, treasureData in ipairs(self.ModData.Maps) do
        self:GenerateTreasure(self.Treasures[i], i, treasureData.Town.Town, treasureData.Town.MapNum)
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

function RicksMLC_TreasureHunt:AddNewTreasureToHunt(treasure, townName)
    local i = #self.ModData.Maps + 1
    self:GenerateTreasure(treasure, i, townName) -- FIXME: Add MapNum when it is part of the TreasureHuntMgr manual treasureHuntDefn
    if not RicksMLC_TreasureHuntDistributions.Instance():IsInDistribution(treasure) then
        --DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt:AddNewTreasureToHunt() Adding item '" .. treasure .. "' to distribution")
        RicksMLC_TreasureHuntDistributions.Instance():AddSingleTreasureToDistribution(treasure)
    end
    self:AddStashMap(self.ModData.Maps[i], i)
end

function RicksMLC_TreasureHunt:FinishHunt()
    self.Finished = true
    self.ModData.Finished = true
    self:SaveModData()
    triggerEvent("RicksMLC_TreasureHunt_Finished", self.TreasureHuntDefn)
end

function RicksMLC_TreasureHunt:GenerateNextTreasureMap()
    local i = #self.ModData.Maps + 1
    if not self.Treasures[i] then
        self:FinishHunt()
        return
    end
    -- FIXME: Need to add the optional MapNum so maps like LV can be used...
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

function RicksMLC_TreasureHunt:GenerateNextMapItem()
    if not self.ModData.Maps then 
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.GenerateNextMapItem() Error: no treasureHunt data for player")
        return
    end

    local treasureData = self.ModData.Maps[self.ModData.CurrentMapNum]
    local stash = StashSystem.getStash(self:GenerateMapName(self.ModData.CurrentMapNum))
    if not stash then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.GenerateNextMapItem() Error: no stash for '" .. self:GenerateMapName(self.ModData.CurrentMapNum) .. "'" )
        return
    end
    local mapItem = InventoryItemFactory.CreateItem("Base.RicksMLC_TreasureMapTemplate")
    mapItem:setMapID(self:GenerateMapName(self.ModData.CurrentMapNum))
    StashSystem.doStashItem(stash, mapItem)
    mapItem:setName(mapItem:getDisplayName() .. ": " .. self.Name .. " [" .. tostring(self.ModData.CurrentMapNum) .. "]")-- treasureItem:getDisplayName())
    mapItem:setCustomName(true)
    return mapItem
end

function RicksMLC_TreasureHunt:IsBuildingVisited()
    local treasureData = self.ModData.Maps[self.ModData.CurrentMapNum]
    local buildingDef = treasureData.Building
    if not buildingDef then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt:IsBuildingVisited() No Building def assigned")
    end
end

function RicksMLC_TreasureHunt:AddNextMapToZombie(zombie)
    --DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.AddNextMapToZombie()")
    self:GenerateNextTreasureMap()
    local mapItem = self:GenerateNextMapItem()
    zombie:addItemToSpawnAtDeath(mapItem)
    -- Check if the building has been visited before now.
    if self:IsBuildingVisited() then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt:AddNextMapToZombie(): WARNING Buiding already visited for map " .. mapItem:getName())
    end
end

function RicksMLC_TreasureHunt:Dump()
    RicksMLC_THSharedUtils.DumpArgs(self.ModData, 0, "RicksMLC_TreasureHunt")

    if self.ModData.Maps[self.ModData.CurrentMapNum] then
        local map = self.ModData.Maps[self.ModData.CurrentMapNum]
        local closestXY = Vector2f:new(1000, 1000)
        local nearestBuildingDef = AmbientStreamManager.instance:getNearestBuilding(map.buildingCentreX,  map.buildingCentreY, closestXY)
        if nearestBuildingDef then
            RicksMLC_StashUtils.Dump(nearestBuildingDef, map.Treasure, map.buildingCentreX,  map.buildingCentreY)
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
    local matchItem = obj.TreasureLookup[x:getType()]
    if matchItem then
        return true
    end
    return false
end

function RicksMLC_TreasureHunt:RecordFoundTreasure(item)
    item:getModData()["RicksMLC_Treasure"] = self:GenerateMapName(self.ModData.CurrentMapNum)
    if self.ModData.CurrentMapNum == #self.Treasures then
        self:FinishHunt()
    else
        self.ModData.CurrentMapNum = self.ModData.CurrentMapNum + 1
        self:SaveModData()
    end
end

function RicksMLC_TreasureHunt:CheckIfNewMapNeeded()
    if self.Finished then return {UnassignedItems = {}, NewMapNeeded = false} end

    local possibleTreasureItems = {}
    -- Check if the current treasure has been added to the player inventory
    if self.ModData.CurrentMapNum == 0 then
        self.ModData.CurrentMapNum = 1
        self:SaveModData()
    else
        local treasureData = self.ModData.Maps[self.ModData.CurrentMapNum]
        local itemContainer = getPlayer():getInventory()
        local itemList = itemContainer:getAllEvalArgRecurse(matchAnyTreasureClosure, self) --treasureData.Treasure)
        if not itemList:isEmpty() then
            for i = 0, itemList:size()-1 do 
                local item = itemList:get(i)
                local currentBuildingDef = getPlayer():getCurrentBuildingDef()
                if currentBuildingDef and treasureData and self:IsSameBuilding(treasureData, currentBuildingDef) then
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

function RicksMLC_TreasureHunt:HandleOnHitZombie(zombie, character, bodyPartType, handWeapon)
    --DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.OnHitZombie()")
    if self.Finished then return false end
    -- Make sure it's not just any character that hits the zombie
    if character == getPlayer() and self.ModData.CurrentMapNum ~= self.ModData.LastSpawnedMapNum then
        self:AddNextMapToZombie(zombie)
        self.ModData.LastSpawnedMapNum = self.ModData.CurrentMapNum
        self:SaveModData()
    end
end

---------------------------------------------
-- Static methods

