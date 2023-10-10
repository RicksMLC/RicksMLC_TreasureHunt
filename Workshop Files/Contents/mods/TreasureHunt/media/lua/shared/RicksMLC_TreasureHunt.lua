-- RicksMLC_TreasureHunt.lua
-- Controls the treasure hunt.

require "StashDescriptions/RicksMLC_TreasureHuntStash"
require "RicksMLC_MapUtils"

RicksMLC_TreasureHunt = {}

RicksMLC_TreasureHunt.Treasures = {
    "BorisBadger",
    "FluffyfootBunny",
    "FreddyFox",
    "FurbertSquirrel",
    "JacquesBeaver",
    "MoleyMole",
    "PancakeHedgehog",
    "Spiffo"
}

RicksMLC_TreasureHunt.MapIDLookup = {}

-- Log the map that is read with the "Read Map" menu.
RicksMLC_TreasureHunt.readingMapID = nil
function RicksMLC_TreasureHunt.GetReadingMap() return RicksMLC_TreasureHunt.readingMapID end
function RicksMLC_TreasureHunt.SetReadingMap(item) RicksMLC_TreasureHunt.readingMapID = item end

function RicksMLC_TreasureHunt.setBoundsInSquares(mapAPI)
    local treasureMaps = getGameTime():getModData()["RicksMLC_TreasureHunt"]
    if not treasureMaps then
        return
    end
    local treasureData = treasureMaps.Maps[treasureMaps.CurrentMapNum]
    local mapID = RicksMLC_TreasureHunt.GetReadingMap()
    if mapID then
        treasureData = treasureMaps.Maps[RicksMLC_TreasureHunt.MapIDLookup[mapID]]
    end
    local dx = 600
    local dy = 500
    if treasureData then
        mapAPI:setBoundsInSquares(treasureData.buildingCentreX - dx, treasureData.buildingCentreY - dy, treasureData.buildingCentreX + dx, treasureData.buildingCentreY + dy)
    end
end

RicksMLC_TreasureHunt.MapDefnFn = function(mapUI)
	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')
	MapUtils.initDefaultStyleV1(mapUI)
	RicksMLC_MapUtils.ReplaceWaterStyle(mapUI)
	RicksMLC_TreasureHunt.setBoundsInSquares(mapAPI)
	MapUtils.overlayPaper(mapUI)
end

local function calcBuildingCentre(buildingDef)
    return {x = buildingDef:getX() + PZMath.roundToInt(buildingDef:getW() / 2),
            y = buildingDef:getY() + PZMath.roundToInt(buildingDef:getH() / 2)}
end

local function isDuplicateBuilding(nearestBuildingDef, existingMaps)

    local buildingCentre = calcBuildingCentre(nearestBuildingDef)
    --DebugLog.log(DebugType.Mod, "nearestBuildingCentre: x: " .. tostring(buildingCentre.x) .. " y: " .. tostring(buildingCentre.y))
    for i, treasureDetails in ipairs(existingMaps) do
        --DebugLog.log(DebugType.Mod, "   x: " .. tostring(treasureDetails.buildingCentreX) .. " y: " .. tostring(treasureDetails.buildingCentreY) )
        if treasureDetails.buildingCentreX == buildingCentre.x and treasureDetails.buildingCentreY == buildingCentre.y then 
           DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt: isDuplicateBuilding detected. x: " .. tostring(treasureDetails.buildingCentreX) .. " y: " .. tostring(treasureDetails.buildingCentreY))
           return true
        end
    end
    return false
end

-- Choose a random buiding for the treasure.
function RicksMLC_TreasureHunt.ChooseRandomBuilding(mapBounds, existingMaps)
    local x = ZombRand(mapBounds.x1, mapBounds.x2)
    local y = ZombRand(mapBounds.y1, mapBounds.y2)
    local closestXY = Vector2f:new(1000, 1000)
    local nearestBuildingDef = AmbientStreamManager.instance:getNearestBuilding(x,  y, closestXY)
    local retries = 20
    while (not nearestBuildingDef or nearestBuildingDef:isHasBeenVisited() or isDuplicateBuilding(nearestBuildingDef, existingMaps) and retries > 0) do
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

function RicksMLC_TreasureHunt.CreateTreasureMap(treasure, mapBounds, existingMaps)
    local treasureData = {}

    treasureData.Building = RicksMLC_TreasureHunt.ChooseRandomBuilding(mapBounds, existingMaps)
    if not treasureData.Building then 
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.CreateTreasureMap ERROR: No building found for mapBounds " .. tostring(mapBounds))
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
function RicksMLC_TreasureHunt.GenerateMapName(i)
    return "RicksMLC_TreasureMap" .. tostring(i)
end

function RicksMLC_TreasureHunt.AddStashMaps(treasureMaps)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.AddStashMaps()")
    local stashLookup = {}
    for i, stashDesc in ipairs(StashDescriptions) do
        stashLookup[stashDesc.name] = stashDesc
    end
    for i, treasureData in ipairs(treasureMaps) do
        -- Check if the stash already exists
        local stashMapName = RicksMLC_TreasureHunt.GenerateMapName(i)
        local stashDesc = stashLookup[stashMapName]
        if not stashDesc then
            --DebugLog.log(DebugType.Mod, "   Adding stash for " .. treasureData.Treasure)
            local newStashMap = RicksMLC_TreasureHuntStash.AddStash(
                stashMapName,
                treasureData.buildingCentreX,
                treasureData.buildingCentreY, 
                treasureData.barricades, 
                "Base." .. stashMapName,
                treasureData.Treasure)
        end
        LootMaps.Init[stashMapName] = RicksMLC_TreasureHunt.MapDefnFn
        RicksMLC_TreasureHunt.MapIDLookup[RicksMLC_TreasureHunt.GenerateMapName(i)] = i
    end
end

function RicksMLC_TreasureHunt.GenerateTreasures()
    if isServer() then 
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.AssignTreasure() isServer() no action")
        return
    end
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.AssignTreasure() Creating treasure maps")
    local i = 1
    local treasureMaps = {}
    for i, treasure in ipairs(RicksMLC_TreasureHunt.Treasures) do
        local randomTown = RicksMLC_MapUtils.GetRandomTown()
        local mapBounds = RicksMLC_MapUtils.GetMapExtents(randomTown.Town, randomTown.MapNum)
        treasureMaps[i] = RicksMLC_TreasureHunt.CreateTreasureMap(treasure, mapBounds, treasureMaps)
        if not treasureMaps[i] then return end -- If no building could be found abort.
        treasureMaps[i].Town = randomTown
    end
    getGameTime():getModData()["RicksMLC_TreasureHunt"] = {CurrentMapNum = 0, Maps = treasureMaps, Finished = false}
end

function RicksMLC_TreasureHunt.InitStashMaps(treasureHunt)
    RicksMLC_TreasureHunt.AddStashMaps(treasureHunt.Maps)
    -- The reinit is necessary when adding a stash after the game is started.
    -- If the StashSystem is not reinitialised the StashSystem.getStash() not find the stash, even if the
    -- stash name is in the StashSystem.getPossibleStashes():get(i):getName()
    
    StashSystem.reinit()
end

function RicksMLC_TreasureHunt.InitTreasureHunt()
    local treasureHunt = getGameTime():getModData()["RicksMLC_TreasureHunt"]
    if not treasureHunt then
        RicksMLC_TreasureHunt.GenerateTreasures()
    end
    treasureHunt = getGameTime():getModData()["RicksMLC_TreasureHunt"]
    if not treasureHunt then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.InitTreasureHunt() ERROR: Failed to Generate treasures")
        return
    end
    RicksMLC_TreasureHunt.InitStashMaps(treasureHunt)
    if RicksMLC_TreasureHunt.CheckPlayerLootForTreasure(getPlayer()) then
        RicksMLC_TreasureHunt.PrepareNextMap()
    end
    RicksMLC_TreasureHunt.Dump(getPlayer())
end

-----------------------------------------------------------------------
-- Functions for finding treasure in the player/container inventory

function RicksMLC_TreasureHunt.FindMissingTreasureItem(itemContainer)
	-- https://projectzomboid.com/modding////zombie/inventory/ItemContainer.html
    for i, treasureType in ipairs(RicksMLC_TreasureHunt.Treasures) do
	    local itemList = itemContainer:getAllTypeRecurse(treasureType)
        if itemList:isEmpty() then
            -- not found, so return it as the next thing to find
            --DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.FindMissingTreasureItem() missing '" .. treasureType .. "'")
            return {TreasureNum = i, Treasure = treasureType}
        end
    end
	return nil
end

function RicksMLC_TreasureHunt.CheckContainerForTreasure(itemContainer)
    local missingTreasureItem = RicksMLC_TreasureHunt.FindMissingTreasureItem(itemContainer)
    local treasureHunt = getGameTime():getModData()["RicksMLC_TreasureHunt"]
    if missingTreasureItem then
        if treasureHunt.CurrentMapNum == missingTreasureItem.TreasureNum then
            -- The missing treasure is already assigned to CurrentMapNum
            --DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.CheckPlayerLootForTreasure() The missing treasure is already assigned to CurrentMapNum: " .. tostring(treasureHunt.CurrentMapNum))
            return false
        end
        treasureHunt.CurrentMapNum = missingTreasureItem.TreasureNum
        return true
    else
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.CheckPlayerLootForTreasure All treasure found.")
        treasureHunt.Finished = true
        return false
    end
end

function RicksMLC_TreasureHunt.CheckPlayerLootForTreasure(player)
	local itemContainer = player:getInventory() -- lootInv is an ISInventoryPage or an ItemContainer
	if not itemContainer then  return false end
	
    return RicksMLC_TreasureHunt.CheckContainerForTreasure(itemContainer)
end

function RicksMLC_TreasureHunt.GenerateNextMap()
    local treasureHunt = getGameTime():getModData()["RicksMLC_TreasureHunt"]
    if not treasureHunt then 
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.GenerateNextMap() Error: no treasureHunt data for player")
        return
    end

    local treasureData = treasureHunt.Maps[treasureHunt.CurrentMapNum]
    local stash = StashSystem.getStash(RicksMLC_TreasureHunt.GenerateMapName(treasureHunt.CurrentMapNum))
    if not stash then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.GenerateNextMap() Error: no stash for '" .. RicksMLC_TreasureHunt.GenerateMapName(treasureHunt.CurrentMapNum) .. "'" )
        return
    end
    local mapItem = InventoryItemFactory.CreateItem("Base.RicksMLC_TreasureMapTemplate")
    local treasureItem = InventoryItemFactory.CreateItem("Base." .. treasureData.Treasure)
    mapItem:setMapID(RicksMLC_TreasureHunt.GenerateMapName(treasureHunt.CurrentMapNum))
    StashSystem.doStashItem(stash, mapItem)
    mapItem:setName(mapItem:getDisplayName() .. ": " .. treasureItem:getDisplayName())
    mapItem:setCustomName(true)
    return mapItem
end

function RicksMLC_TreasureHunt.AddNextMapToZombie(zombie)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.AddNextMapToZombie()")
    local mapItem = RicksMLC_TreasureHunt.GenerateNextMap()
    zombie:addItemToSpawnAtDeath(mapItem)
end

function RicksMLC_TreasureHunt.PrepareNextMap()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.PrepareNextMap()")
    
    local treasureHunt = getGameTime():getModData()["RicksMLC_TreasureHunt"]
    if treasureHunt.Finished then return end

    -- Clear the event so we don't add more than one.
    Events.OnHitZombie.Remove(RicksMLC_TreasureHunt.OnHitZombie)
    Events.OnHitZombie.Add(RicksMLC_TreasureHunt.OnHitZombie)
end

function RicksMLC_TreasureHunt.Dump(player)
    local treasureHunt = getGameTime():getModData()["RicksMLC_TreasureHunt"]
    --RicksMLC_SharedUtils.DumpArgs(treasureHunt, 0, "RicksMLC_TreasureHunt")

    -- FIXME: Remove this debugging code for pre-reinit test:
    -- DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.Dump() StashSystem.getPossibleStashes()")
    -- for i=0,StashSystem.getPossibleStashes():size()-1 do
    --     local stash = StashSystem.getStash(StashSystem.getPossibleStashes():get(i):getName())
    --     if not stash then
    --         DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.Dump() stash '" .. StashSystem.getPossibleStashes():get(i):getName() .. "' not found StashSystem.init()")
    --     else
    --         DebugLog.log(DebugType.Mod, "   Stash: " .. tostring(i) .. " " .. stash:getName())
    --     end
    -- end

    if treasureHunt.Maps[treasureHunt.CurrentMapNum] then
        local map = treasureHunt.Maps[treasureHunt.CurrentMapNum]
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
        RicksMLC_TreasureHunt.AddNextMapToZombie(zombie)
        Events.OnHitZombie.Remove(RicksMLC_TreasureHunt.OnHitZombie)
    end
end

function RicksMLC_TreasureHunt.OnCreatePlayer(playerIndex, player)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.OnCreatePlayer start")
    local treasureHunt = getGameTime():getModData()["RicksMLC_TreasureHunt"]
    if treasureHunt then
        treasureHunt.CurrentMapNum = 0
    end
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.OnCreatePlayer end")
end

function RicksMLC_TreasureHunt.OnKeyPressed(key)
    if key == Keyboard.KEY_F10 then
        -- FIXME: Reset() does not work.  Maybe it never will and should not.
        --RicksMLC_TreasureHunt.GenerateTreasures()
        --RicksMLC_TreasureHunt.Dump(getPlayer())
    end
end

function RicksMLC_TreasureHunt.HandleTransferActionPerform()
    --DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.HandleItemTransfer()")
    local treasureHunt = getGameTime():getModData()["RicksMLC_TreasureHunt"]
    if treasureHunt.Finished then return end

    if RicksMLC_TreasureHunt.CheckPlayerLootForTreasure(getPlayer()) then
        RicksMLC_TreasureHunt.PrepareNextMap()
    end
end

function RicksMLC_TreasureHunt.OnGameStart()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.OnGameStart start")
    RicksMLC_TreasureHunt.InitTreasureHunt()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.OnGameStart end")
end

Events.OnGameStart.Add(RicksMLC_TreasureHunt.OnGameStart)
--Events.OnKeyPressed.Add(RicksMLC_TreasureHunt.OnKeyPressed)
Events.OnCreatePlayer.Add(RicksMLC_TreasureHunt.OnCreatePlayer)

