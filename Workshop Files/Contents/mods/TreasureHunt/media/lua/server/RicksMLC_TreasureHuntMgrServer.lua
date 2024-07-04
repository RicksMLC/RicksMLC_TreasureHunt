-- RicksMLC_TreasureHuntMgrServer.lua
-- General stages for a treasure hunt:
--  1) Register the treasure hunt definitions
--  2) Register treasure hunt RicksMLC_TreasureHunt:AddStashMap (uses the StashUtil.new() to add to the StashSystem)
--  3) StashSystem.reinit() to read the updated stash info into the system.  Make sure to do this before calling getStash()
--  4) Create the treasure map item
--  5) stash = getStash() and doStashItem(stash, item)
--
-- Server side treaure hunt manager
-- 1) init treasure hunts definitions
-- 2) tell clients about registered treasure hunts
-- 3) sends a signal to the clients to make maps. ie: SetOnHitZombieForNewMap() 
-- 4) The client intitates the map making. eg: Client OnHitZombie -> sendClientCommand("ClientOnHitZombie")
-- 5) Server runs HandleClientOnHitZombie()
--       -> CreateClientInitiatedMapItems() 
--              calls each treasureHunt:HandleClientOnHitZombie() which turns the defn into the actual map (building etc) item, and calls the Stash system on the server.
--       Makes the list of created mapItems for each treasureHunt which requires a map
-- 6) sendServerCommand("MapItemsGenerated", args) with the mapItemList
-- 7) Client assigns the generated maps to the hit zombie.

if not isServer() or isClient() then return end

DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer: Server code used")

-- Inherits from RicksMLC_TreasureHuntMgr.  The overridden methods facilitate the client/server communications needed
-- to co-ordinate the mgr status and synchronise between the clients and the server.

require "RicksMLC_TreasureHuntMgr"

RicksMLC_TreasureHuntMgrServer = RicksMLC_TreasureHuntMgr:derive("RicksMLC_TreasureHuntMgrServer");

-- Override the base class Instance() so any calls on the server will use the server version.
function RicksMLC_TreasureHuntMgr.Instance()
    if not RicksMLC_TreasureHuntMgrInstance then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr.Instance() using RicksMLC_TreasureHuntMgrServer:new()")
        RicksMLC_TreasureHuntMgrInstance = RicksMLC_TreasureHuntMgrServer:new()
    end
    return RicksMLC_TreasureHuntMgrInstance
end

function RicksMLC_TreasureHuntMgrServer:new()
    local this = RicksMLC_TreasureHuntMgr.new(self)
    return this
end

function RicksMLC_TreasureHuntMgrServer:RecreateMapItem(mapItemDetails)
    -- {mapItem = mapItem, stashMapName = mapItem:getMapID(), huntId = self.HuntId, i = self.ModData.CurrentMapNum}
    local mapItem = InventoryItemFactory.CreateItem("Base.RicksMLC_TreasureMapTemplate")
    mapItem:setMapID(mapItemDetails.stashMapName)
    mapItem:setName(mapItemDetails.displayName)-- treasureItem:getDisplayName())
    mapItem:setCustomName(true)
    return mapItem
end

function RicksMLC_TreasureHuntMgrServer:SetWaitingToHitZombie(value)
    RicksMLC_TreasureHuntMgr.SetWaitingToHitZombie(self, value)
    self:SendMgrServerStatus(nil, nil)
end

function RicksMLC_TreasureHuntMgrServer.SetOnHitZombieForNewMap()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer.SetOnHitZombieForNewMap() Server sending Waiting to hit a zombie")
    self:SetWaitingToHitZombie(true)
    local args = {}
    sendServerCommand("RicksMLC_TreasureHuntMgr", "SetOnHitZombieForNewMap", args)
end

function RicksMLC_TreasureHuntMgrServer:HandleOnAddTreasureHunt(newTreasureHunt)
        -- Override this on the server and client.
        -- local checkResult = newTreasureHunt:CheckIfNewMapNeeded(getPlayer()) -- Note: This is a client-only function
        -- if checkResult.NewMapNeeded then
        --     RicksMLC_TreasureHuntMgr.SetOnHitZombieForNewMap()
        -- end
    
        --triggerEvent("RicksMLC_TreasureHuntMgr_AddTreasureHunt")
    local args = {NewTreasureHunt = newTreasureHunt}
    sendServerCommand("RicksMLC_TreasureHuntMgrClient", "AddTreasureHunt", args)
end

function RicksMLC_TreasureHuntMgrServer:CreateClientInitiatedMapItems(player, args)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer:CreateClientInitiatedMapItems()")
    local mapItemList = {}
    for i, treasureHunt in ipairs(self.TreasureHunts) do
        local mapItemDetails = treasureHunt:HandleClientOnHitZombie(player, nil)
        if mapItemDetails then
            DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer:CreateClientInitiatedMapItems() " .. treasureHunt.Name .. " mapItemDetails created")
            mapItemList[#mapItemList+1] = mapItemDetails
        else
            DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer:CreateClientInitiatedMapItems() " .. treasureHunt.Name .. " no mapItemDetails")
        end
    end
    return mapItemList
end

function RicksMLC_TreasureHuntMgrServer:HandleClientOnHitZombie(player, args)
    -- Server has received a message that the client has hit a zombie
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer:HandleClientOnHitZombie()")

    self:SetWaitingToHitZombie(false)
    local mapItemList = self:CreateClientInitiatedMapItems(player, args)
    local replyArgs = {playerNum = player:getPlayerNum(), mapItemList = mapItemList}
    RicksMLC_THSharedUtils.DumpArgs(replyArgs, 0, "RicksMLC_TreasureHuntMgrServer:HandleClientOnHitZombie() replyArgs")
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer:HandleClientOnHitZombie()")
    sendServerCommand("RicksMLC_TreasureHuntMgrClient", "MapItemsGenerated", replyArgs)
end

function RicksMLC_TreasureHuntMgrServer:SendTreasureHuntList(player, args)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer:SendTreasureHuntList() requestor: '" .. tostring(args.requestor) .. "'")
    local treasureHuntList = {}
    for i, treasureHunt in ipairs(self.TreasureHunts) do
        treasureHuntList[i] = treasureHunt:GetCurrentTreasureHuntInfo() 
    end
    local retArgs = {playerNum = player:getPlayerNum(), data = treasureHuntList}
    RicksMLC_THSharedUtils.DumpArgs(retArgs, 0, "SentTreasureHuntList")
    sendServerCommand(args.requestor, "SentTreasureHuntList", retArgs)
end

function RicksMLC_TreasureHuntMgrServer:SendTreasureHuntInfo(player, args)
    local thInfo = {}
    -- FIXME: This may be incorrect as the index of the returned data is not the index requested.  This may turn into an out of sequence error.
    if args.index then
        thInfo[1] = self.TreasureHunts[args.index]:GetCurrentTreasureHuntInfo()
    else
        for i, treasureHunt in ipairs(self.TreasureHunts) do
            thInfo[i] = treasureHunt:GetCurrentTreasureHuntInfo()
        end
    end
    local retArgs = {playerNum = player:getPlayerNum(), data = thInfo}
    sendServerCommand(args.requestor, "SentTreasureHuntInfo", retArgs)
end

function RicksMLC_TreasureHuntMgrServer:SendMgrServerStatus(player, args)
    -- if player is nil, send the message to all clients
    local retArgs = {playerNum = (player and player:getPlayerNum()) or nil, data = {isWaitingToHitZombie = self.IsWaitingToHitZombie}}
    --FIXME: Remove?  This msg can be sent without a request (ie when status changes) 
    --sendServerCommand(args.requestor, "SentMgrServerStatus", retArgs)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer:SendMgrServerStatus() player:" .. tostring(player) .. " retArgs player num:" .. tostring(retArgs.playerNum) .. " data: " .. tostring(retArgs.data.isWaitingToHitZombie))
    sendServerCommand("RicksMLC_Cache", "SentMgrServerStatus", retArgs)
end

function RicksMLC_TreasureHuntMgrServer:RecordFoundTreasure(huntId, mapNum)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer:RecordFoundTreasure() huntId:" .. tostring(huntId) )
    if huntId > #self.TreasureHunts then
        DebugLog.log(DebugType.Mod, "   huntId invalid:" .. tostring(#self.TreasureHunts))
        return
    end
    self.TreasureHunts[huntId]:FinishOrSetNextMap()
    if self.TreasureHunts[huntId]:IsNewMapNeeded() then
        self:SetWaitingToHitZombie()
    end
end

-------------------------------------
-- Static methdods

function RicksMLC_TreasureHuntMgrServer.OnClientCommand(moduleName, command, player, args)
    -- Receive a message from a client
    --DebugLog.log(DebugType.Mod, 'RicksMLC_TreasureHuntMgrServer.OnClientCommand() ' .. moduleName .. "." .. command)
    if moduleName ~= "RicksMLC_TreasureHuntMgrServer" then return end

    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer.OnClientCommand: " .. moduleName .. ", " .. command)
    if command == "ClientOnHitZombie" then
        RicksMLC_TreasureHuntMgr.Instance():HandleClientOnHitZombie(player, args)
        return
    end
    if command == "RecordFoundTreasure" then
        RicksMLC_TreasureHuntMgr.Instance():RecordFoundTreasure(args.huntId, args.mapNum)
        return
    end
    if command == "RequestTreasureHuntsList" then
        RicksMLC_TreasureHuntMgr.Instance():SendTreasureHuntList(player, args)
        return
    end
    if command == "RequestTreasureHuntsInfo" then
        RicksMLC_TreasureHuntMgr.Instance():SendTreasureHuntInfo(player, args)
        return
    end
    if command == "RequestMgrServerStatus" then
        RicksMLC_TreasureHuntMgr.Instance():SendMgrServerStatus(player, args)
        return
    end
end

Events.OnClientCommand.Add(RicksMLC_TreasureHuntMgrServer.OnClientCommand)

function RicksMLC_TreasureHuntMgrServer.OnServerStarted()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer.OnServerStarted()")
    RicksMLC_TreasureHuntMgr.Instance()
    -- Create and AmbientStreamManager on the server.  The AmbientStreamManager is used by the TreasureHunt to calculate the closest building
    -- but the AmbientStreamManager in vanilla PZ only exists on the client side.  Therefore we create one here if it does not already exist.
    if not AmbientStreamManager.instance then
        AmbientStreamManager.instance = AmbientStreamManager:new()
        if AmbientStreamManager then
            DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer.OnServerStarted(): AmbientStreamManager.instance created")
        else
            DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer.OnServerStarted(): AmbientStreamManager.instance not created")
        end
    else
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer.OnServerStarted(): AmbientStreamManager.instance already exists")
    end

    -- Kick off the base class EveryOneMinuteAtStart to initialise this TreasureHuntMgr on the server.
    Events.EveryOneMinute.Add(RicksMLC_TreasureHuntMgr.EveryOneMinuteAtStart)
end

local function TreasureHuntMgrInitDone()
    DebugLog.log(DebugType.Mod, "server RicksMLC_TreasureHuntMgr_InitDone event detected")
end

local function TreasureHuntMgrPreInit()
    DebugLog.log(DebugType.Mod, "server RicksMLC_TreasureHuntMgr_PreInit event detected")
end

local function TreasureHuntMgrInitAddTreasureHunt(treasureHuntDefn)
    DebugLog.log(DebugType.Mod, "server RicksMLC_TreasureHuntMgr_AddTreasureHunt event detected")
    RicksMLC_THSharedUtils.DumpArgs(treasureHuntDefn, 0, "Added TreasureHuntDefn")
end

Events.OnServerStarted.Add(RicksMLC_TreasureHuntMgrServer.OnServerStarted)

Events.RicksMLC_TreasureHuntMgr_InitDone.Add(TreasureHuntMgrInitDone)
Events.RicksMLC_TreasureHuntMgr_PreInit.Add(TreasureHuntMgrPreInit)
Events.RicksMLC_TreasureHuntMgr_AddTreasureHunt.Add(TreasureHuntMgrInitAddTreasureHunt)

