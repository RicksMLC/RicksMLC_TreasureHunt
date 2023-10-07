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

RicksMLC_TreasureHunt.MapIDLookup = { }

-- Log the map that is read with the "Read Map" menu.
RicksMLC_TreasureHunt.readingMapID = nil
function RicksMLC_TreasureHunt.GetReadingMap() return RicksMLC_TreasureHunt.readingMapID end
function RicksMLC_TreasureHunt.SetReadingMap(item) RicksMLC_TreasureHunt.readingMapID = item end

function RicksMLC_TreasureHunt.setBoundsInSquares(mapAPI)
    --mapAPI:setBoundsInSquares(7970, 7130, 8869, 7889) -- Get from the Debug Map Bounds?
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


-- Choose a random buiding for the treasure.
-- Param: map: Optional.  Restrict the selection to the given map extents
function RicksMLC_TreasureHunt.ChooseRandomBuilding(mapBounds)
    local x = ZombRand(mapBounds.x1, mapBounds.x2)
    local y = ZombRand(mapBounds.y1, mapBounds.y2)
    local closestXY = Vector2f:new(1000, 1000)
    local nearestBuildingDef = AmbientStreamManager.instance:getNearestBuilding(x,  y, closestXY)
    local retries = 20
    while (not nearestBuildingDef or nearestBuildingDef:isHasBeenVisited()) and retries > 0 do
        x = ZombRand(mapBounds.x1, mapBounds.x2)
        y = ZombRand(mapBounds.y1, mapBounds.y2)
        nearestBuildingDef = AmbientStreamManager.instance:getNearestBuilding(x,  y, closestXY)
        retries = retries - 1
    end
    
    if not nearestBuildingDef then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.ChooseRandomBuilding() Error. No buildings within bounds " 
                    .. " x1: " .. tostring(mapBounds.x1) .. " x2: " .. tostring(mapBounds.x2) 
                    .. " y1: " .. tostring(mapBounds.y1) .. " y2: " .. tostring(mapBounds.y2))
        return nil
    end
    return nearestBuildingDef
end

function RicksMLC_TreasureHunt.CreateTreasureMap(treasure, mapBounds)
    local treasureData = {}

    treasureData.Building = RicksMLC_TreasureHunt.ChooseRandomBuilding(mapBounds)
    if not treasureData.Building then 
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.CreateTreasureMap ERROR: No building found for mapBounds " .. tostring(mapBounds))
    end

    treasureData.Treasure = treasure
    treasureData.barricades = ZombRand(100)
    treasureData.buildingCentreX = treasureData.Building:getX() + PZMath.roundToInt(treasureData.Building:getW() / 2)
    treasureData.buildingCentreY = treasureData.Building:getY() + PZMath.roundToInt(treasureData.Building:getH() / 2)
    return treasureData
end

 -- This is the name of the map item TODO: Generate a unique name and assign the same name to the mapItem
function RicksMLC_TreasureHunt.GenerateMapName(i)
    return "RicksMLC_TreasureMap" .. tostring(i)
end

function RicksMLC_TreasureHunt.AddStashMaps(treasureMaps)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.AddStashMaps()")
    for i, treasureData in ipairs(treasureMaps) do
        -- Check if the stash already exists
        local stash = StashSystem.getStash(RicksMLC_TreasureHunt.GenerateMapName(i))
        if not stash then
            local newStashMap = RicksMLC_TreasureHuntStash.AddStash(
                RicksMLC_TreasureHunt.GenerateMapName(i),
                treasureData.buildingCentreX,
                treasureData.buildingCentreY, 
                treasureData.barricades, 
                "Base." .. RicksMLC_TreasureHunt.GenerateMapName(i),
                treasureData.Treasure)
        end
        LootMaps.Init[RicksMLC_TreasureHunt.GenerateMapName(i)] = RicksMLC_TreasureHunt.MapDefnFn
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
        treasureMaps[i] = RicksMLC_TreasureHunt.CreateTreasureMap(treasure, mapBounds)
        treasureMaps[i].Town = randomTown
        local mapName = RicksMLC_TreasureHunt.GenerateMapName(i)
    end

    getGameTime():getModData()["RicksMLC_TreasureHunt"] = {CurrentMapNum = 0, Maps = treasureMaps}
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
end

-----------------------------------------------------------------------
-- Functions for finding treasure in the player/container inventory

function RicksMLC_TreasureHunt.FindMissingTreasureItem(itemContainer)
	-- https://projectzomboid.com/modding////zombie/inventory/ItemContainer.html
    for i, treasureType in ipairs(RicksMLC_TreasureHunt.Treasures) do
	    local itemList = itemContainer:getAllTypeRecurse(treasureType)
        if itemList:isEmpty() then
            -- not found, so return it as the next thing to find
            return {TreasureNum = i, Treasure = treasureType}
        end
    end
	return nil
end

function RicksMLC_TreasureHunt.CheckContainerForTreasure(itemContainer)
    local missingTreasureItem = RicksMLC_TreasureHunt.FindMissingTreasureItem(itemContainer)
    if missingTreasureItem then
        local treasureHunt = getGameTime():getModData()["RicksMLC_TreasureHunt"]
        if treasureHunt.CurrentMapNum == missingTreasureItem.TreasureNum then
            -- The missing treasure is already assigned to CurrentMapNum
            return false
        end
        treasureHunt.CurrentMapNum = missingTreasureItem.TreasureNum -- FIXME: This may be a bit dodgy using the Inventory event check
        return true
    else
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.CheckPlayerLootForTreasure All tresaure found.")
        return false
    end
end

function RicksMLC_TreasureHunt.CheckPlayerLootForTreasure(player)
	local itemContainer = player:getInventory() -- lootInv is an ISInventoryPage or an ItemContainer
	if not itemContainer then  return false end
	
    return RicksMLC_TreasureHunt.CheckContainerForTreasure(itemContainer)
end

function RicksMLC_TreasureHunt.AddCurrentMapToInventory(player)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.AddCurrentMapToInventory()")
    RicksMLC_TreasureHunt.Dump(player)

    local treasureHunt = getGameTime():getModData()["RicksMLC_TreasureHunt"]
    if not treasureHunt then 
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.AddCurrentMapToInventory() Error: no treasureHunt data for player")
        return
    end

    -- Check which treasure is missing, and make that the current treasure map to find.
    if RicksMLC_TreasureHunt.CheckPlayerLootForTreasure(player) then
        local mapItem = RicksMLC_TreasureHunt.GenerateNextMap()
        player:getInventory():AddItem(mapItem)
    else
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.AddCurrentMapToInventory() No more treasure to find.")
    end

    -- From AdHocCmds Vending ... not sure if it applies here.
    --self.invPage.inventoryPane.inventory:AddItem(self.prize)
    -- if isClient() then
    --     -- Also add the item on the server otherwise it will disapear from the player inventory after transfer from vending machine directly to the player inventory
    --     player:getInventory():addItemOnServer(mapItem)
    -- end
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
    Events.OnHitZombie.Add(RicksMLC_TreasureHunt.OnHitZombie)
end

function RicksMLC_TreasureHunt.OnHitZombie(zombie, character, bodyPartType, handWeapon)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.OnHitZombie()")
    RicksMLC_TreasureHunt.AddNextMapToZombie(zombie)
    Events.OnHitZombie.Remove(RicksMLC_TreasureHunt.OnHitZombie)
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
        RicksMLC_TreasureHunt.OnCreatePlayer(1, getPlayer()) -- FIXME: Remove when create player works.
        --RicksMLC_TreasureHunt.AddCurrentMapToInventory(getPlayer())
    end
end

-- Should use a different event to check for the treasure and prepare next map.
function RicksMLC_TreasureHunt.OnRefreshInventoryWindowContainers(invPage, state)
	-- ISInventoryPage invPage, string State
	if state == "end" then
    	if not invPage.isCollapsed then
            if RicksMLC_TreasureHunt.CheckPlayerLootForTreasure(getPlayer()) then
                RicksMLC_TreasureHunt.PrepareNextMap()
            end			
		end
	end
end

function RicksMLC_TreasureHunt.OnGameStart()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.OnGameStart start")
    RicksMLC_TreasureHunt.InitTreasureHunt()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.OnGameStart end")
end

function RicksMLC_TreasureHunt.Dump(player)
    local treasureHunt = getGameTime():getModData()["RicksMLC_TreasureHunt"]
    RicksMLC_SharedUtils.DumpArgs(treasureHunt, 0, "RicksMLC_TreasureHunt")

    -- FIXME: Remove this debugging code for pre-reinit test:
    -- DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.AssignTreasure() AddStash done pre-re-init")
    -- for i=0,StashSystem.getPossibleStashes():size()-1 do
    --     DebugLog.log(DebugType.Mod, "   Stash: " .. tostring(i) .. " " .. StashSystem.getPossibleStashes():get(i):getName())
    --     local stash = StashSystem.getStash(StashSystem.getPossibleStashes():get(i):getName())
    --     if stash then 
    --         DebugLog.log(DebugType.Mod, "   Stash: " .. tostring(i) .. " " .. stash:getName())
    --     else
    --         DebugLog.log(DebugType.Mod, "   No stash for : " .. tostring(i) .. " " .. StashSystem.getPossibleStashes():get(i):getName())
    --     end
    -- end

    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.Dump() StashSystem.getPossibleStashes()")
    for i=0,StashSystem.getPossibleStashes():size()-1 do
        local stash = StashSystem.getStash(StashSystem.getPossibleStashes():get(i):getName())
        if not stash then
            DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.Dump() stash '" .. StashSystem.getPossibleStashes():get(i):getName() .. "' not found StashSystem.init()")
        else
            DebugLog.log(DebugType.Mod, "   Stash: " .. tostring(i) .. " " .. stash:getName())
        end
    end

end

Events.OnGameStart.Add(RicksMLC_TreasureHunt.OnGameStart)
Events.OnKeyPressed.Add(RicksMLC_TreasureHunt.OnKeyPressed)
Events.OnRefreshInventoryWindowContainers.Add(RicksMLC_TreasureHunt.OnRefreshInventoryWindowContainers)
Events.OnCreatePlayer.Add(RicksMLC_TreasureHunt.OnCreatePlayer)

