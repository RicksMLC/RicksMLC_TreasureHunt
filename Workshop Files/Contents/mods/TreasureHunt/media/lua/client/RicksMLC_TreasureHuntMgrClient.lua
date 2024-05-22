-- RicksMLC_TreasureHuntMgrClient.lua
--
-- Client side treasure hunt manager for MP
-- Inherits from the shared treasure hunt manager, and facilitates the client/server comms from the client side.
--
-- 

if not isClient() then return end

require "RicksMLC_TreasureHuntMgr"

RicksMLC_TreasureHuntMgrClient = RicksMLC_TreasureHuntMgr:derive("RicksMLC_TreasureHuntMgrClient")

-- Override the base class Instance() so client actions are performed
function RicksMLC_TreasureHuntMgr.Instance()
    if not RicksMLC_TreasureHuntMgrInstance then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr.Instance() using RicksMLC_TreasureHuntMgrClient:new()")    
        RicksMLC_TreasureHuntMgrInstance = RicksMLC_TreasureHuntMgrClient:new()
    end
    return RicksMLC_TreasureHuntMgrInstance
end

function RicksMLC_TreasureHuntMgrClient:new()
    local this = RicksMLC_TreasureHuntMgr.new(self)
    this.HitZombie = nil
    return this
end

function RicksMLC_TreasureHuntMgrClient:CallTreasureHuntHandleOnHitZombie(zombie, character, bodyPartType, handWeapon)
    -- Currently: The client generates a map if it needs one.  The generated map(s) are passed to the server for recording.

    local generatedMapList = {}
    for i, treasureHunt in ipairs(self.TreasureHunts) do
        local mapItemDetails = treasureHunt:HandleOnHitZombie(zombie, character, bodyPartType, handWeapon, false) -- doStash = false for client.  The server handles the doStashItem() call
        if mapItemDetails then
            -- FIXME: No need to call on map creation.
            --treasureHunt:AddStashToStashUtil(mapItemDetails.treasureModData, mapItemDetails.i, mapItemDetails.stashMapName)
            mapItemDetails.Index = i
            DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient.HandleOnHitZombie() generated new map " .. mapItemDetails.stashMapName)
            generatedMapList[#generatedMapList+1] = mapItemDetails
        end
    end
    return generatedMapList
end

function RicksMLC_TreasureHuntMgrClient:HandleOnHitZombie(zombie, character, bodyPartType, handWeapon)
    -- Note: OnHitZombie is a client-side event
    -- this is the client side of the mgr
    -- Send the OnHitZombie message to the server
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient.HandleOnHitZombie()")
    self.HitZombie = zombie
    
    -- TODO: What should happen here?  The player has hit the zombie which should trigger the generation of the map
    -- but should it generate locally and pass it to the server, or pass to the server to generate and send
    -- back to this client? For now it passes to the base class, which is on the client side at this point.
    -- It will call for each treasure hunt to HandleOnHitZombie which will generate the appropriate map(s) and 
    -- add to the zombie SpawnItemOnDeath.
    --RicksMLC_TreasureHuntMgr.HandleOnHitZombie(self, zombie, character)
    -- else
   
    -- FIXME: Commented out for now to experiment with generating the map item on the server. 
    -- local generatedMapList = self:CallTreasureHuntHandleOnHitZombie(zombie, character, bodyPartType, handWeapon)
    --local args = {zombie = zombie, character = character, bodyPartType = bodyPartType, handWeapon = handWeapon, generatedMapList = generatedMapList}

    local args = {zombie = zombie, character = character, bodyPartType = bodyPartType, handWeapon = handWeapon}
    RicksMLC_THSharedUtils.DumpArgs(args, 0, "Sending ClientOnHitZombie args")
    sendClientCommand(getPlayer(), "RicksMLC_TreasureHuntMgrServer", "ClientOnHitZombie", args)
    -- end
    --
end

function RicksMLC_TreasureHuntMgrClient:RecreateMapItem(mapItemDetails)
    -- {mapItem = mapItem, stashMapName = mapItem:getMapID(), huntId = self.HuntId, i = self.ModData.CurrentMapNum}
    local mapItem = InventoryItemFactory.CreateItem("Base.RicksMLC_TreasureMapTemplate")
    mapItem:setMapID(mapItemDetails.stashMapName)
    --FIXME: Does the client need to update the stashsystem?
    --StashSystem.doStashItem(stash, mapItem) -- Copies the stash.annotations to the java layer stash object and removes from potential stashes.
    mapItem:setName(mapItemDetails.mapItem:getDisplayName())-- treasureItem:getDisplayName())
    mapItem:setCustomName(true)
    return mapItem
end

function RicksMLC_TreasureHuntMgrClient:UpdateLootMapsInitFn(stashMapName, huntId, i)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient:UpdateLootMapsInitFn() " .. stashMapName)
    LootMaps.Init[stashMapName] = RicksMLC_TreasureHunt.MapDefnFn
    RicksMLC_MapIDLookup.Instance():AddMapID(stashMapName, huntId, i)
end

function RicksMLC_TreasureHuntMgrClient:UpdateTreasureHuntMap(mapItemDetails)
    for i, treasureHunt in ipairs(self.TreasureHunts) do
        if treasureHunt.Name == mapItemDetails.Name then
            treasureHunt.ModData.Maps = mapItemDetails.Maps
            treasureHunt.ModData.LastSpawnedMapNum = treasureHunt.ModData.CurrentMapNum
        end
    end
end

function RicksMLC_TreasureHuntMgrClient:HandleOnMapItemsGenerated(args)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient.HandleOnMapItemsGenerated()")
    RicksMLC_THSharedUtils.DumpArgs(args, 0, "HandleOnMapItemsGenerated args")
    if getPlayer():getPlayerNum() == args.playerNum then
        if args.mapItemList then
            for _, mapItemDetails in ipairs(args.mapItemList) do
                --local mapItem = self:RecreateMapItem(mapItemDetails)
                mapItem = mapItemDetails.mapItem
                self:UpdateTreasureHuntMap(mapItemDetails)
                self:UpdateLootMapsInitFn(mapItemDetails.stashMapName, mapItemDetails.huntId, mapItemDetails.i)
                if self.HitZombie then
                    self.HitZombie:addItemToSpawnAtDeath(mapItem)
                end
            end
        end
    end
    self.HitZombie = nil
end

function RicksMLC_TreasureHuntMgrClient:CheckAndSetOnHitZombie(clientTreasureHunt)
    local checkResult = clientTreasureHunt:CheckIfNewMapNeeded(getPlayer()) -- Note: This is a client-only function
    if checkResult.NewMapNeeded then
        RicksMLC_TreasureHuntMgr.SetOnHitZombieForNewMap()
    end
end

function RicksMLC_TreasureHuntMgrClient:AddTreasureHuntFromServer(newTreasureHunt)
    -- Add this new treasure hunt to the mgr client.
    -- TODO: Populate the client reflected manager with the newTreasureHunt?
    RicksMLC_THSharedUtils.DumpArgs(newTreasureHunt, 0, "RicksMLC_TreasureHuntMgrClient:AddTreasureHuntFromServer() newTreasureHunt")
    local treasureHuntDefn = newTreasureHunt.TreasureHuntDefn
    local clientTreasureHunt = RicksMLC_TreasureHuntMgr.Instance():AddTreasureHunt(treasureHuntDefn, true) -- Say it is from stored modData so this client does not store it in the ModData

    -- Update the client treasure hunt info with the server info (ModData etc?)
    
    RicksMLC_THSharedUtils.DumpArgs(clientTreasureHunt, 0, "Added clientTreasureHunt")
    self:CheckAndSetOnHitZombie(clientTreasureHunt)
end

function RicksMLC_TreasureHuntMgrClient.OnServerCommand(moduleName, command, args)
    -- Received a message from the server
	if moduleName ~= "RicksMLC_TreasureHuntMgrClient" then return end

    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient.OnServerCommand: " .. moduleName .. ", " .. command)
    if command == "AddTreasureHunt" then
        RicksMLC_TreasureHuntMgr:Instance():AddTreasureHuntFromServer(args.NewTreasureHunt)
        return
    end
    if command == "MapItemsGenerated" then
        -- Response from the server with the generated map item
        RicksMLC_TreasureHuntMgrClient:Instance():HandleOnMapItemsGenerated(args)
        return
    end
    if command == "ServerResponseToOnHitZombie" then
        
        return
    end
end

Events.OnServerCommand.Add(RicksMLC_TreasureHuntMgrClient.OnServerCommand)

function RicksMLC_TreasureHuntMgrClient.OnGameStart()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient.OnGameStart()")
    RicksMLC_TreasureHuntMgr.Instance()
    triggerEvent("RicksMLC_TreasureHuntMgr_PreInit")
    -- TODO: Initialise the connection to the treasure hunt manager server side
end

local function TreasureHuntMgrInitDone()
    DebugLog.log(DebugType.Mod, "client RicksMLC_TreasureHuntMgr_InitDone event detected")
end

local function TreasureHuntMgrPreInit()
    DebugLog.log(DebugType.Mod, "client RicksMLC_TreasureHuntMgr_PreInit event detected")
end

local function TreasureHuntMgrInitAddTreasureHunt(treasureHuntDefn)
    DebugLog.log(DebugType.Mod, "client RicksMLC_TreasureHuntMgr_AddTreasureHunt event detected")
    RicksMLC_THSharedUtils.DumpArgs(treasureHuntDefn, 0, "Added TreasureHuntDefn")
end

Events.OnGameStart.Add(RicksMLC_TreasureHuntMgrClient.OnGameStart)

Events.RicksMLC_TreasureHuntMgr_InitDone.Add(TreasureHuntMgrInitDone)
Events.RicksMLC_TreasureHuntMgr_PreInit.Add(TreasureHuntMgrPreInit)
Events.RicksMLC_TreasureHuntMgr_AddTreasureHunt.Add(TreasureHuntMgrInitAddTreasureHunt)


--- Test:
local function TestSettingOnHit(key)
    if key == Keyboard.KEY_F9 then
        for _, treasureHunt in ipairs(RicksMLC_TreasureHuntMgr.Instance().TreasureHunts) do
            treasureHunt:ResetLastSpawnedMapNum()
            RicksMLC_TreasureHuntMgr.Instance():CheckAndSetOnHitZombie(treasureHunt)
        end
    end
end

Events.OnKeyPressed.Add(TestSettingOnHit)