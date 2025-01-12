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

RicksMLC_TreasureHuntMgrServer = RicksMLC_TreasureHuntMgr:derive("RicksMLC_TreasureHuntMgrServer")

-- Override the base class Instance() so any calls on the server will use the server version.
function RicksMLC_TreasureHuntMgr.Instance()
    if not RicksMLC_TreasureHuntMgrInstance then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr.Instance() using RicksMLC_TreasureHuntMgrServer:new()")
        RicksMLC_TreasureHuntMgrInstance = RicksMLC_TreasureHuntMgrServer:new()
    end
    return RicksMLC_TreasureHuntMgrInstance
end

function RicksMLC_TreasureHuntMgrServer:new()
    local o = RicksMLC_TreasureHuntMgr.new(self)
    setmetatable(o, self)
    self.__index = self

    o.tempRestrictToPlayer = nil

    return o
end

-- Create a TreasureHuntServer object for the server mgr
function RicksMLC_TreasureHuntMgrServer:NewTreasureHunt(treasureHuntDefn, huntId)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer:NewTreasureHunt(): '" .. treasureHuntDefn.Name .. "'")
    local treasureHunt = RicksMLC_TreasureHuntServer:new(treasureHuntDefn, huntId)
    return treasureHunt
end


function RicksMLC_TreasureHuntMgrServer:RecreateMapItem(mapItemDetails)
    -- {mapItem = mapItem, stashMapName = mapItem:getMapID(), huntId = self.HuntId, i = self.ModData.CurrentMapNum}
    local mapItem = instanceItem("Base.RicksMLC_TreasureMapTemplate")
    mapItem:setMapID(mapItemDetails.stashMapName)
    mapItem:setName(mapItemDetails.displayName)-- treasureItem:getDisplayName()
    mapItem:setCustomName(true)
    return mapItem
end

function RicksMLC_TreasureHuntMgrServer:SetWaitingToHitZombie(isWaiting, treasureHunt, player)
    if isWaiting then
        -- FIXME: Handle the player waiting for hitting zombie.
    else
        -- FIXME: Handle the reset.
    end
    RicksMLC_TreasureHuntMgr.SetWaitingToHitZombie(self, isWaiting, treasureHunt)
    self:SendMgrServerStatus(nil, nil)
end

function RicksMLC_TreasureHuntMgrServer:HandleOnAddTreasureHunt(newTreasureHunt)
    -- Override to mask out - the server does not handle the AddTreasureHunt event
end

function RicksMLC_TreasureHuntMgrServer:SetOnHitZombieForNewMap(treasureHunt)
    -- This override does not call the base class SetOnHitZombieForNewMap as that method only applies to the client-side.
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer.SetOnHitZombieForNewMap() Server sending Waiting to hit a zombie")
    self:SetWaitingToHitZombie(true, treasureHunt)
    local args = {treasureHunt = treasureHunt, player = nil} -- FIXME: How do we know which player on the server?
    -- TODO: MP: Check this is the correct player
    sendServerCommand("RicksMLC_TreasureHuntMgrClient", "SetOnHitZombieForNewMap", args)
end

function RicksMLC_TreasureHuntMgrServer:SendAddedTreasureHuntToClients(newTreasureHunt)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer:SendAddedTreasureHuntToClients() '" .. newTreasureHunt.Name .. "'")
    local args = {NewTreasureHunt = newTreasureHunt}
    --RicksMLC_THSharedUtils.DumpArgs(args, 0, "RicksMLC_TreasureHuntMgrServer: sendServerCommand: AddTreasureHuntFromServer args")
    sendServerCommand("RicksMLC_TreasureHuntMgrClient", "AddTreasureHuntFromServer", args)
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

    self:SetWaitingToHitZombie(false, nil, player)
    local mapItemList = self:CreateClientInitiatedMapItems(player, args)
    local replyArgs = {playerUsername = player:getUsername(), mapItemList = mapItemList}
    --RicksMLC_THSharedUtils.DumpArgs(replyArgs, 0, "RicksMLC_TreasureHuntMgrServer:HandleClientOnHitZombie() replyArgs")
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
    --RicksMLC_THSharedUtils.DumpArgs(retArgs, 0, "SentTreasureHuntList")
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

function RicksMLC_TreasureHuntMgrServer:RecordFoundTreasure(huntId, mapNum, player)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer:RecordFoundTreasure() huntId:" .. tostring(huntId) )
    if huntId > #self.TreasureHunts then
        DebugLog.log(DebugType.Mod, "   huntId invalid:" .. tostring(#self.TreasureHunts))
        return
    end
    self.TreasureHunts[huntId]:FinishOrSetNextMap()
    if self.TreasureHunts[huntId]:IsNewMapNeeded() then
        self:SetWaitingToHitZombie(true, self.TreasureHunts[huntId])
    else
        if self.TreasureHunts[huntId].Finished then
            DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer:RecordFoundTreasure() Finished huntId:" .. tostring(huntId) )
            local args = {Name = self.TreasureHunts[huntId].Name, PlayerUsername = player:getUsername()}
            sendServerCommand("RicksMLC_TreasureHuntMgrClient", "FinishTreasureHunt", args)
        end
    end
end

function RicksMLC_TreasureHuntMgrServer.GetPlayer(userName, verbose)
    --DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer.GetPlayer() userName: " .. userName)
    local player = getPlayerFromUsername(userName)
    if not player then
        if verbose then DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer.GetPlayer() Error: player username '" .. userName .. "' not found.  Current users:") end
        local playerList = getOnlinePlayers()
        for i = 0, playerList:size()-1 do
            if verbose then  DebugLog.log(DebugType.Mod, "  Username '" .. playerList:get(i):getUsername() .. "'")  end
            if playerList:get(i):getUsername() == userName then
                if verbose then DebugLog.log(DebugType.Mod, "  Username '" .. playerList:get(i):getUsername() .. "' found ¯\_(ツ)_/¯ ") end
                player = playerList:get(i)
                break
            end
        end
    end
    --DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer.GetPlayer() player:getUserName(): " .. player:getUsername())
    return player
end

function RicksMLC_TreasureHuntMgrServer.GetRandomPlayer()
    local playerList = getOnlinePlayers()
    if playerList:size() == 0 then return nil end

    local num = ZombRand(0, playerList:size()-1)
    return playerList:get(num)
end

-- FIXME: This is probably wrong for already defined treasure hunts as they may already be restricted to a player
function RicksMLC_TreasureHuntMgrServer:AddTreasureHunt(treasureHuntDefn, isFromModData)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer:AddTreasureHunt() tempRestrictToPlayer: " .. ((self.tempRestrictToPlayer and self.tempRestrictToPlayer:getUsername()) or "nil"))


    local treasureHunt = RicksMLC_TreasureHuntMgr.AddTreasureHunt(self, treasureHuntDefn, isFromModData)
    return treasureHunt
end

function RicksMLC_TreasureHuntMgrServer:AddTreasureHuntFromClient(player, args)
    -- Call the base class AddTreasureHunt() to manually add the one sent from the client
    --RicksMLC_THSharedUtils.DumpArgs(args, 0, "RicksMLC_TreasureHuntMgrServer:AddTreasureHuntFromClient() args")
    local treasureHunt = self:AddTreasureHunt(args.treasureHuntDefn, false)

    if treasureHunt and args.treasureHuntDefn.Player and treasureHunt:GetMode() ~= "ChaosRace" then
        local restrictPlayer = RicksMLC_TreasureHuntMgrServer.GetPlayer(args.treasureHuntDefn.Player, true) or player
        treasureHunt:RestrictMapToPlayer(restrictPlayer)
        --DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer:AddTreasureHuntFromClient() restrictPlayer: " .. restrictPlayer:getUsername())
    end
    self:SendAddedTreasureHuntToClients(treasureHunt)
end

function RicksMLC_TreasureHuntMgrServer:HandleRequestInitTreasureHunts(player, args)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer:HandleRequestInitTreasureHunts() Sending InitialTreasureHunts")
    local args = {}
    args.treasureHuntList = {}
    for i, treasureHunt in ipairs(self.TreasureHunts) do
        args.treasureHuntList[#args.treasureHuntList+1] = treasureHunt
    end
    sendServerCommand("RicksMLC_TreasureHuntMgrClient", "InitialTreasureHunts", args)
end

-- Testing function for the server to send test args in response to a test request from the client
function RicksMLC_TreasureHuntMgrServer:HandleSimulateOnHitZombie(player, args)
    for i, treasureHunt in ipairs(self.TreasureHunts) do
        if treasureHunt.Name == "TEST_MAPSPAWN" then
            -- Rest the map so it will spawn
            treasureHunt:ResetLastSpawnedMapNum()
            local mapItem = treasureHunt:GenerateNextMapItem(false)
            local mapItemDetails = treasureHunt:MakeMapItemDetails(mapItem)
            -- Simulate the response to an on hit zombie.  This should spawn the map on the client player
            local retArgs = {playerUsername = player:getUsername(), mapItemList = {mapItemDetails}}
            sendServerCommand("RicksMLC_TreasureHuntMgrClient", "MapItemsGenerated", retArgs)
            return
        end
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
        RicksMLC_TreasureHuntMgr.Instance():RecordFoundTreasure(args.huntId, args.mapNum, player)
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
    if command == "AddTreasureHuntFromClient" then
        RicksMLC_TreasureHuntMgr.Instance():AddTreasureHuntFromClient(player, args)
        return
    end
    if command == "RequestInitTreasureHunts" then
        RicksMLC_TreasureHuntMgr.Instance():HandleRequestInitTreasureHunts(player, args)
        return
    end
    if command == "SimulateOnHitZombie" then
        RicksMLC_TreasureHuntMgr.Instance():HandleSimulateOnHitZombie(player, args)
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


Events.OnServerStarted.Add(RicksMLC_TreasureHuntMgrServer.OnServerStarted)

Events.RicksMLC_TreasureHuntMgr_InitDone.Add(TreasureHuntMgrInitDone)
Events.RicksMLC_TreasureHuntMgr_PreInit.Add(TreasureHuntMgrPreInit)


