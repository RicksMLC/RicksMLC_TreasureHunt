-- RicksMLC_TreasureHunt.lua
-- Controls the treasure hunt.

require "StashDescriptions/RicksMLC_TreasureHuntStash"
require "RicksMLC_MapUtils"

require "ISBaseObject"

RicksMLC_TreasureHunt = ISBaseObject:derive("RicksMLC_TreasureHunt");

RicksMLC_TreasureHuntInstance = nil

function RicksMLC_TreasureHunt.Instance()
    if not RicksMLC_TreasureHuntInstance then
        RicksMLC_TreasureHuntInstance = RicksMLC_TreasureHunt:new()
    end
    return RicksMLC_TreasureHuntInstance
end

function RicksMLC_TreasureHunt:new()
	local o = {}
	setmetatable(o, self)
	self.__index = self

    o.Treasures = {
        "BorisBadger",
        "FluffyfootBunny",
        "FreddyFox",
        "FurbertSquirrel",
        "JacquesBeaver",
        "MoleyMole",
        "PancakeHedgehog",
        "Spiffo"
    }

    o.MapIDLookup = {}
    o.readingMapID = nil

    o.ModData = nil

    o.Initialised = false

    return o
end

-- Persistent Storage: 
-- getGameTime():getModData()["RicksMLC_TreasureHunt"] = {CurrentMapNum = 0, Maps = treasureMaps, Finished = false}

-- SetReadingMap is the external static function called by the override for the Read Map menu item.
function RicksMLC_TreasureHunt.SetReadingMap(item) RicksMLC_TreasureHunt.Instance().readingMapID = item end
function RicksMLC_TreasureHunt:GetReadingMap() return self.readingMapID end

function RicksMLC_TreasureHunt:setBoundsInSquares(mapAPI)
    if not self.ModData.Maps then
        return
    end
    local treasureData = self.ModData.Maps[self.ModData.CurrentMapNum]
    local mapID = self:GetReadingMap()
    if mapID then
        treasureData = self.ModData.Maps[self.MapIDLookup[mapID]]
    end
    local dx = 600
    local dy = 500
    if treasureData then
        mapAPI:setBoundsInSquares(treasureData.buildingCentreX - dx, treasureData.buildingCentreY - dy, treasureData.buildingCentreX + dx, treasureData.buildingCentreY + dy)
    end
end

-- Map function for the LootMaps.Init[stashMapName] = RicksMLC_TreasureHunt.MapDefnFn
-- This is part of what ties the map to the stash.
RicksMLC_TreasureHunt.MapDefnFn = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')
	MapUtils.initDefaultStyleV1(mapUI)
	RicksMLC_MapUtils.ReplaceWaterStyle(mapUI)
	RicksMLC_TreasureHunt.Instance():setBoundsInSquares(mapAPI)
	MapUtils.overlayPaper(mapUI)
end

local function calcBuildingCentre(buildingDef)
    return {x = buildingDef:getX() + PZMath.roundToInt(buildingDef:getW() / 2),
            y = buildingDef:getY() + PZMath.roundToInt(buildingDef:getH() / 2)}
end

function RicksMLC_TreasureHunt:IsDuplicateBuilding(nearestBuildingDef)
    local buildingCentre = calcBuildingCentre(nearestBuildingDef)
    --DebugLog.log(DebugType.Mod, "nearestBuildingCentre: x: " .. tostring(buildingCentre.x) .. " y: " .. tostring(buildingCentre.y))
    for i, treasureDetails in ipairs(self.ModData.Maps) do
        --DebugLog.log(DebugType.Mod, "   x: " .. tostring(treasureDetails.buildingCentreX) .. " y: " .. tostring(treasureDetails.buildingCentreY) )
        if treasureDetails.buildingCentreX == buildingCentre.x and treasureDetails.buildingCentreY == buildingCentre.y then 
           DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt: isDuplicateBuilding detected. x: " .. tostring(treasureDetails.buildingCentreX) .. " y: " .. tostring(treasureDetails.buildingCentreY))
           return true
        end
    end
    return false
end

-- Choose a random buiding for the treasure.
function RicksMLC_TreasureHunt:ChooseRandomBuilding(mapBounds)
    local x = ZombRand(mapBounds.x1, mapBounds.x2)
    local y = ZombRand(mapBounds.y1, mapBounds.y2)
    local closestXY = Vector2f:new(1000, 1000)
    local nearestBuildingDef = AmbientStreamManager.instance:getNearestBuilding(x,  y, closestXY)
    local retries = 20
    while (not nearestBuildingDef or nearestBuildingDef:isHasBeenVisited() or self:IsDuplicateBuilding(nearestBuildingDef) and retries > 0) do
        x = ZombRand(mapBounds.x1, mapBounds.x2)
        y = ZombRand(mapBounds.y1, mapBounds.y2)
        nearestBuildingDef = AmbientStreamManager.instance:getNearestBuilding(x,  y, closestXY)
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
    treasureData.Treasure = treasure
    treasureData.barricades = ZombRand(100)
    local buildingCentre = calcBuildingCentre(treasureData.Building)
    treasureData.buildingCentreX = buildingCentre.x
    treasureData.buildingCentreY = buildingCentre.y
    return treasureData
end

 -- This is the name of the map item 
function RicksMLC_TreasureHunt:GenerateMapName(i)
    return "RicksMLC_TreasureMap" .. tostring(i)
end

function RicksMLC_TreasureHunt:AddStashMaps()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.AddStashMaps()")
    local stashLookup = {}
    for i, stashDesc in ipairs(StashDescriptions) do
        stashLookup[stashDesc.name] = stashDesc
    end
    for i, treasureData in ipairs(self.ModData.Maps) do
        -- Check if the stash already exists
        local stashMapName = self:GenerateMapName(i)
        local stashDesc = stashLookup[stashMapName]
        if not stashDesc then
            DebugLog.log(DebugType.Mod, "   Adding stash for " .. treasureData.Treasure)
            local newStashMap = RicksMLC_TreasureHuntStash.AddStash(
                stashMapName,
                treasureData.buildingCentreX,
                treasureData.buildingCentreY, 
                treasureData.barricades, 
                "Base." .. stashMapName,
                treasureData.Treasure)
        else
            DebugLog.log(DebugType.Mod, "  Found stash for " .. treasureData.Treasure)
            RicksMLC_SharedUtils.DumpArgs(stashDesc, 0, "Existing Stash Details")
        end
        LootMaps.Init[stashMapName] = RicksMLC_TreasureHunt.MapDefnFn
        self.MapIDLookup[self:GenerateMapName(i)] = i
    end
end

function RicksMLC_TreasureHunt:GenerateTreasures()
    if isServer() then 
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.GenerateTreasures() isServer() no action")
        return
    end
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.GenerateTreasures() Creating treasure maps begin")
    for i, treasure in ipairs(self.Treasures) do
        if self.ModData.Maps[i] then
            DebugLog.log(DebugType.Mod, "    Existing treasure: " .. treasure .. " " .. self.ModData.Maps[i].Town.Town)
        else
            local randomTown = RicksMLC_MapUtils.GetRandomTown()
            local mapBounds = RicksMLC_MapUtils.GetMapExtents(randomTown.Town, randomTown.MapNum)
            self.ModData.Maps[i] = self:CreateTreasureData(treasure, mapBounds)
            if not self.ModData.Maps[i] then return end -- If no building could be found abort.
            self.ModData.Maps[i].Town = randomTown
            DebugLog.log(DebugType.Mod, "    New treasure: "  .. treasure .. " " .. self.ModData.Maps[i].Town.Town)
        end
    end
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.GenerateTreasures() End")
end

function RicksMLC_TreasureHunt:InitStashMaps()
    self:AddStashMaps()
    -- The reinit is necessary when adding a stash after the game is started.
    -- If the StashSystem is not reinitialised the StashSystem.getStash() not find the stash, even if the
    -- stash name is in the StashSystem.getPossibleStashes():get(i):getName()
    
    StashSystem.reinit()
end

function RicksMLC_TreasureHunt:LoadModData()
    self.ModData = getGameTime():getModData()["RicksMLC_TreasureHunt"]
    if not self.ModData then
        self.ModData = {CurrentMapNum = 0, Maps = {}, Finished = false}
    end
    return self.ModData
end

function RicksMLC_TreasureHunt:SaveModData()
    getGameTime():getModData()["RicksMLC_TreasureHunt"] = self.ModData
end

function RicksMLC_TreasureHunt:InitTreasureHunt()
    self:LoadModData()
    self:GenerateTreasures()
    if not self.ModData.Maps then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.InitTreasureHunt() ERROR: Failed to Generate treasures")
        return
    end
    self:SaveModData()
    self.Initialised = true
    RicksMLC_SharedUtils.DumpArgs(self.ModData, 0, "InitTreasureHunt post GenerateTreasures")
    self:InitStashMaps()
    if self:CheckPlayerLootForTreasure(getPlayer()) then
        self:PrepareNextMap()
    end
end

-----------------------------------------------------------------------
-- Functions for finding treasure in the player/container inventory

function RicksMLC_TreasureHunt:FindMissingTreasureItem(itemContainer)
	-- https://projectzomboid.com/modding////zombie/inventory/ItemContainer.html
    for i, treasureType in ipairs(self.Treasures) do
	    local itemList = itemContainer:getAllTypeRecurse(treasureType)
        if itemList:isEmpty() then
            -- not found, so return it as the next thing to find
            --DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.FindMissingTreasureItem() missing '" .. treasureType .. "'")
            return {TreasureNum = i, Treasure = treasureType}
        end
    end
	return nil
end

function RicksMLC_TreasureHunt:CheckContainerForTreasure(itemContainer)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.CheckContainerForTreasure()")
    local missingTreasureItem = self:FindMissingTreasureItem(itemContainer)
    if missingTreasureItem then
        if self.ModData.CurrentMapNum == missingTreasureItem.TreasureNum then
            -- The missing treasure is already assigned to CurrentMapNum
            return false
        end
        self.ModData.CurrentMapNum = missingTreasureItem.TreasureNum
        self:SaveModData()
        return true
    else
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.CheckPlayerLootForTreasure All treasure found.")
        self.Finished = true
        return false
    end
end

function RicksMLC_TreasureHunt:CheckPlayerLootForTreasure(player)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.CheckPlayerLootForTreasure()")
	local itemContainer = player:getInventory() -- lootInv is an ISInventoryPage or an ItemContainer
	if not itemContainer then return false end
	
    return self:CheckContainerForTreasure(itemContainer)
end

function RicksMLC_TreasureHunt:GenerateNextMap()
    if not self.ModData.Maps then 
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.GenerateNextMap() Error: no treasureHunt data for player")
        return
    end

    local treasureData = self.ModData.Maps[self.ModData.CurrentMapNum]
    local stash = StashSystem.getStash(self:GenerateMapName(self.ModData.CurrentMapNum))
    if not stash then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.GenerateNextMap() Error: no stash for '" .. self:GenerateMapName(self.ModData.CurrentMapNum) .. "'" )
        return
    end
    local mapItem = InventoryItemFactory.CreateItem("Base.RicksMLC_TreasureMapTemplate")
    local treasureItem = InventoryItemFactory.CreateItem("Base." .. treasureData.Treasure)
    mapItem:setMapID(self:GenerateMapName(self.ModData.CurrentMapNum))
    StashSystem.doStashItem(stash, mapItem)
    mapItem:setName(mapItem:getDisplayName() .. ": " .. treasureItem:getDisplayName())
    mapItem:setCustomName(true)
    return mapItem
end

function RicksMLC_TreasureHunt:AddNextMapToZombie(zombie)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.AddNextMapToZombie()")
    local mapItem = self:GenerateNextMap()
    zombie:addItemToSpawnAtDeath(mapItem)
end

function RicksMLC_TreasureHunt:PrepareNextMap()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.PrepareNextMap()")
    
    if self.Finished then return end

    -- Clear the event so we don't add more than one.
    Events.OnHitZombie.Remove(RicksMLC_TreasureHunt.OnHitZombie)
    Events.OnHitZombie.Add(RicksMLC_TreasureHunt.OnHitZombie)
end

function RicksMLC_TreasureHunt:Dump()
    RicksMLC_SharedUtils.DumpArgs(self.ModData, 0, "RicksMLC_TreasureHunt")

    if self.ModData.Maps[self.ModData.CurrentMapNum] then
        local map = self.ModData.Maps[self.ModData.CurrentMapNum]
        local closestXY = Vector2f:new(1000, 1000)
        local nearestBuildingDef = AmbientStreamManager.instance:getNearestBuilding(map.buildingCentreX,  map.buildingCentreY, closestXY)
        if nearestBuildingDef then
            RicksMLC_StashUtils.Dump(nearestBuildingDef, map.Treasure, map.buildingCentreX,  map.buildingCentreY)
        end
    end
end

---------------------------------------------
-- Static methods

function RicksMLC_TreasureHunt.OnHitZombie(zombie, character, bodyPartType, handWeapon)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.OnHitZombie()")
    -- Make sure it's not just any character that hits the zombie
    if character == getPlayer() then
        RicksMLC_TreasureHunt.Instance():AddNextMapToZombie(zombie)
        Events.OnHitZombie.Remove(RicksMLC_TreasureHunt.OnHitZombie)
    end
end

function RicksMLC_TreasureHunt.OnCreatePlayer(playerIndex, player)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.OnCreatePlayer start " .. tostring(playerIndex))
    if RicksMLC_TreasureHunt.Instance().Initialised and RicksMLC_TreasureHunt.Instance().ModData then
        RicksMLC_TreasureHunt.Instance().ModData.CurrentMapNum = 0
    end
    --RicksMLC_TreasureHunt.Instance():Dump()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.OnCreatePlayer end")
end

function RicksMLC_TreasureHunt.HandleTransferActionPerform()
    if RicksMLC_TreasureHunt.Instance().Finished then return end

    if RicksMLC_TreasureHunt.Instance():CheckPlayerLootForTreasure(getPlayer()) then
        RicksMLC_TreasureHunt.Instance():PrepareNextMap()
    end
end

function RicksMLC_TreasureHunt.OnGameStart()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.OnGameStart start")
    --RicksMLC_TreasureHunt.Instance():InitTreasureHunt()
    Events.EveryOneMinute.Add(RicksMLC_TreasureHunt.EveryOneMinuteAtStart)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.OnGameStart end")
end

local startCount = 0
function RicksMLC_TreasureHunt.EveryOneMinuteAtStart()
    startCount = startCount + 1
    if startCount < 3 then return end
    RicksMLC_TreasureHunt.Instance():InitTreasureHunt()
    Events.EveryOneMinute.Remove(RicksMLC_TreasureHunt.EveryOneMinuteAtStart)
end

function RicksMLC_TreasureHunt.OnKeyPressed(key)
    if key == Keyboard.KEY_F10 then
        --RicksMLC_TreasureHunt.Instance():InitTreasureHunt()
        RicksMLC_TreasureHunt.OnCreatePlayer()
        RicksMLC_TreasureHunt.Instance():Dump()
    end
end

Events.OnGameStart.Add(RicksMLC_TreasureHunt.OnGameStart)
Events.OnKeyPressed.Add(RicksMLC_TreasureHunt.OnKeyPressed)
Events.OnCreatePlayer.Add(RicksMLC_TreasureHunt.OnCreatePlayer)

