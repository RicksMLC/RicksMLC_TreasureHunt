-- RicksMLC_TreasureHuntMgrClient.lua
--
-- Client side treasure hunt manager for MP
-- Inherits from the shared treasure hunt manager, and facilitates the client/server comms from the client side.
--
-- Cache data from the server so the UI can show the server status.
--
-- Game modes: Map generation is the key to the various game modes. 
--      Choose a random player to generate the map
--      Chat integration - a designated player gets the map generation
--  TODO: make sure only one client generates the map for the hunt.  
--    [ ] Test what happens if there is a race condition and two clients generate a map at the same time.
--    [ ] Re-generate a treasure map if it is "lost" eg: missed or destroyed.  Maybe triggered by 
--        the map not appearing in any inventory for a given time?
--    [ ] Store the decorator data in the item instead of the treasure hunt (if it is not already)
--      

if not isClient() then return end

require "RicksMLC_TreasureHuntMgr"

RicksMLC_Cache = ISBaseObject:derive("RicksMLC_Cache")

LuaEventManager.AddEvent("RicksMLC_CacheRefreshed")

RicksMLC_Cache.ErrorCodes = {}
RicksMLC_Cache.ErrorCodes["Error1"] = "Cache is waiting for refresh data"
RicksMLC_Cache.ErrorCodes["Error2"] = "Cache is dirty - refresh request sent"
RicksMLC_Cache.ErrorCodes["Error3"] = "Cache item not found: "
RicksMLC_Cache.ErrorCodes["Error4"] = "Cache is empty - no data."
RicksMLC_Cache.ErrorCodes["Error5"] = "Cache is nil - no data."

function RicksMLC_Cache:new(serverCommandModule, serverRequestCommand, serverResponseCommand, isList)
	local o = {}
	setmetatable(o, self)
	self.__index = self

    o.isList = isList
    o.isDirty = true
    o.idle = true
    o.waitingForData = false
    o.serverCommandModule = serverCommandModule
    o.serverRequestCommand = serverRequestCommand
    o.serverResponseCommand = serverResponseCommand

    o.cache = {}
    o.error = nil

    Events.OnServerCommand.Add(function(moduleName, command, args) RicksMLC_TreasureHuntMgr.Instance().serverTreasureHuntsCache:OnServerCommand(moduleName, command, args) end)

    return o
end

function RicksMLC_Cache:OnServerCommand(moduleName, command, args)
    if moduleName == "RicksMLC_Cache" then
        --DebugLog.log(DebugType.Mod, "RicksMLC_Cache:OnServerCommand '" .. command .. "' playerNum: " .. tostring(args.playerNum))
        if command == self.serverResponseCommand and (args.playerNum == nil or args.playerNum == getPlayer():getPlayerNum()) then
            self:RefreshCache(args.data)
        end
    end
end

function RicksMLC_Cache:ForceCacheUpdate()
    local args = {requestor = "RicksMLC_Cache"}
    sendClientCommand(getPlayer(), self.serverCommandModule, self.serverRequestCommand, args)
    self.waitingForData = true
    self.isDirty = false
    self.idle = false
    self.error = nil
end

function RicksMLC_Cache:RefreshCache(data)
    self.cache = data
    self.isDirty = false
    self.waitingForData = false
    self.idle = true
    self.error = nil
    triggerEvent("RicksMLC_CacheRefreshed", self.serverCommandModule, self.serverRequestCommand, self.serverResponseCommand) 
end

function RicksMLC_Cache:GetLastError()
    return RicksMLC_Cache.ErrorCodes[self.error]
end

-- Return the data at index.  If nil returned, check the cache Error status
function RicksMLC_Cache:GetCachedData(index)
    local retList = {data = nil, error = nil}
    self.error = nil -- Reset the error code for the new data

    if self.waitingForData then
        self.error = "Error1" 
    elseif self.isDirty then
        self:ForceCacheUpdate()
        self.error = "Error2"
    elseif self.cache == nil then
        self.error = "Error5"
    elseif index == nil then
        if self.isList and #self.cache == 0 then
            self.error = "Error4"
        else
            retList.data = self.cache
        end
    elseif not self.cache[index] then
        self.error = "Error3"
    else
        retList.data = self.cache[index]
    end
    retList.error = (self.error and RicksMLC_Cache.ErrorCodes[self.error] .. " " .. self.serverRequestCommand) or nil
    return retList
end

----------------------------------------------------------
-- RicksMLC_TreasureHuntMgrClient
----------------------------------------------------------

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
    local o = RicksMLC_TreasureHuntMgr:new()
    setmetatable(o, self)
	self.__index = self

    o.HitZombie = nil
    o.serverTreasureHuntsCache = RicksMLC_Cache:new("RicksMLC_TreasureHuntMgrServer", "RequestTreasureHuntsList", "SentTreasureHuntList", true)
    Events.OnServerCommand.Add(function(moduleName, command, args) o.serverTreasureHuntsCache:OnServerCommand(moduleName, command, args) end)

    o.serverMgrStatusCache = RicksMLC_Cache:new("RicksMLC_TreasureHuntMgrServer", "RequestMgrServerStatus", "SentMgrServerStatus", false)
    Events.OnServerCommand.Add(function(moduleName, command, args) o.serverMgrStatusCache:OnServerCommand(moduleName, command, args) end)

    return o
end

-- Create a TreasureHuntClient object for the client mgr
function RicksMLC_TreasureHuntMgrClient:NewTreasureHunt(treasureHuntDefn, huntId)
    return RicksMLC_TreasureHuntClient:new(treasureHuntDefn, huntId)
end

function RicksMLC_TreasureHuntMgrClient:GetMgrStatusFromServer()
    local status = {text = "", error = nil}
    if self.serverMgrStatusCache then
        local cachedData = self.serverMgrStatusCache:GetCachedData()
        if cachedData.error then
            status.error = "Error: " .. cachedData.error
        else
            if cachedData.data.isWaitingToHitZombie then
                status.text = "Server Waiting to hit zombie"
            end
        end
    else
        status.error = "serverMgrStatusCache not found"
    end
    return status
end

function RicksMLC_TreasureHuntMgrClient:SetWaitingToHitZombie(isWaiting, treasureHunt)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient:SetWaitingToHitZombie() " .. ((isWaiting and "isWaiting") or "notIsWaiting"))
    -- FIXME: the server should pass in which player this restriction is for...
    local player = getPlayer()
    if not isWaiting then
        -- FIXME: Must check if the map is for the player to unrestrict
        for i, treasureHunt in ipairs(self.TreasureHunts) do
            if treasureHunt.RestrictMapForUser == treasureHunt:GetPlayerId(player) then
                treasureHunt:UnrestrictMapForPlayers()
            end
        end
    else
        treasureHunt:RestrictMapToPlayer(player)
    end

    -- FIXME: Pass the player restriction to the server

    RicksMLC_TreasureHuntMgr.SetWaitingToHitZombie(self, isWaiting, treasureHunt)
end

function RicksMLC_TreasureHuntMgrClient:HandleOnHitZombie(zombie, character, bodyPartType, handWeapon)
    -- Note: OnHitZombie is a client-side event
    -- this is the client side of the mgr
    -- Send the OnHitZombie message to the server so the server can generate the map from the defn and register it in the StashSystem

    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient.HandleOnHitZombie()")
    self.HitZombie = zombie
    
    local args = {zombie = zombie, character = character, bodyPartType = bodyPartType, handWeapon = handWeapon}
    RicksMLC_THSharedUtils.DumpArgs(args, 0, "Sending ClientOnHitZombie args")
    sendClientCommand(getPlayer(), "RicksMLC_TreasureHuntMgrServer", "ClientOnHitZombie", args)
    self:SetWaitingToHitZombie(false)
end

function RicksMLC_TreasureHuntMgrClient:RecreateMapItem(mapItemDetails)
    -- {mapItem = mapItem, stashMapName = mapItem:getMapID(), huntId = self.HuntId, i = self.ModData.CurrentMapNum}
    local mapItem = InventoryItemFactory.CreateItem("Base.RicksMLC_TreasureMapTemplate")
    mapItem:setMapID(mapItemDetails.stashMapName)
    -- The sever makes the mapItemDetails in RicksMLC_TreasureHunt:AddNextMapToZombie(zombie, doStash)
    -- The server RicksMLC_TreasureHuntServer:GenerateNextMapItem(doStash) has a comment stating it calls the base with doStash = false as it expects the doStashItem to be done on the client.
    --  DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient:RecreateMapItem() item name: '" .. mapItem:getDisplayName() .. "'")
    -- doStashItem() uses the mapItem.customName to do the lookup, run doStashItem() after setting the name.
    local stash = StashSystem.getStash(mapItemDetails.stashMapName)
    if not stash then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient:RecreateMapItem() ERROR: no stash for '" .. tostring(mapItemDetails.stashMapName) .. "'")
    end
    StashSystem.doStashItem(stash, mapItem) -- Copies the stash.annotations to the java layer stash object and removes from potential stashes.
    mapItem:setName(mapItemDetails.displayName) -- Must setName() after calling doStashItem() otherwise the map display will be "Annotated Map"
    mapItem:setCustomName(true)
    return mapItem
end

function RicksMLC_TreasureHuntMgrClient:UpdateLootMapsInitFn(stashMapName, huntId, i)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient:UpdateLootMapsInitFn() " .. stashMapName)
    LootMaps.Init[stashMapName] = RicksMLC_TreasureHunt.MapDefnFn
    RicksMLC_MapIDLookup.Instance():AddMapID(stashMapName, huntId, i)
end

function RicksMLC_TreasureHuntMgrClient:UpdateTreasureHuntMap(mapItemDetails)
    --DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient:UpdateTreasureHuntMap()")
    for i, treasureHunt in ipairs(self.TreasureHunts) do
        if treasureHunt.Name == mapItemDetails.name then
            treasureHunt.ModData.Maps = mapItemDetails.Maps
            treasureHunt.ModData.LastSpawnedMapNum = treasureHunt.ModData.CurrentMapNum
            treasureHunt:AddStashFromServer()
        end
    end
end

function RicksMLC_TreasureHuntMgrClient:HandleOnMapItemsGenerated(args)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient.HandleOnMapItemsGenerated() self.HitZombie: " .. tostring(self.HitZombie))
    RicksMLC_THSharedUtils.DumpArgs(args, 0, "HandleOnMapItemsGenerated args")
    if getPlayer():getPlayerNum() == args.playerNum then
        if args.mapItemList then
            for _, mapItemDetails in ipairs(args.mapItemList) do
                self:UpdateTreasureHuntMap(mapItemDetails)
                self:UpdateLootMapsInitFn(mapItemDetails.stashMapName, mapItemDetails.huntId, mapItemDetails.i)
                local mapItem = self:RecreateMapItem(mapItemDetails)
                if self.HitZombie then
                    if self.HitZombie:isDead() then
                        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient.HandleOnMapItemsGenerated() isDead. map: " .. mapItem:getDisplayName())
                        self.HitZombie:getInventory():addItem(mapItem)
                    else
                        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient.HandleOnMapItemsGenerated() not dead. map: " .. mapItem:getDisplayName())
                        self.HitZombie:addItemToSpawnAtDeath(mapItem)
                    end
                end
            end
        end
    end
    self.HitZombie = nil
end

function RicksMLC_TreasureHuntMgrClient:RecordFoundTreasure(huntId, foundMapNum)
    -- Inform the server the treasure hunt item has been found.
    local args = {huntId = huntId, mapNum = foundMapNum}
    sendClientCommand(getPlayer(), "RicksMLC_TreasureHuntMgrServer", "RecordFoundTreasure", args)
end

function RicksMLC_TreasureHuntMgrClient:CheckAndSetOnHitZombie(clientTreasureHunt)
    local checkResult = clientTreasureHunt:CheckIfNewMapNeeded(getPlayer()) -- Note: This is a client-only function
    if checkResult.NewMapNeeded then
        -- TODO: MP: Check this is the correct player
        self:SetOnHitZombieForNewMap(clientTreasureHunt)
    end
end

function RicksMLC_TreasureHuntMgrClient:AddTreasureHunt(treasureHuntDefn)
    -- Client created treasure hunt (eg: from the AdHocCmds)
    -- Send the info to the server so it creates the treasure hunt and forwards to all clients
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient:AddTreasureHunt() '" .. treasureHuntDefn.Name .. "'")
    local args = {treasureHuntDefn = treasureHuntDefn}
    sendClientCommand(getPlayer(), "RicksMLC_TreasureHuntServer", "AddTreasureHuntFromClient", args)
end

function RicksMLC_TreasureHuntMgrClient:AddTreasureHuntFromServer(newTreasureHunt)
    -- Add this new treasure hunt to the mgr client.
    -- Populate the client reflected manager with the newTreasureHunt.
    RicksMLC_THSharedUtils.DumpArgs(newTreasureHunt, 0, "RicksMLC_TreasureHuntMgrClient:AddTreasureHuntFromServer() newTreasureHunt")
    local treasureHuntDefn = newTreasureHunt.TreasureHuntDefn

    -- Call the base class
    local clientTreasureHunt = RicksMLC_TreasureHuntMgr.AddTreasureHunt(self, treasureHuntDefn, true) -- Say it is from stored modData so this client does not store it in the ModData
    if not clientTreasureHunt then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient:AddTreasureHuntFromServer() ERROR: clientTreasureHunt is nil.  Is this a duplicate treasure hunt?" .. treasureHuntDefn.Name)
        return
    end
    -- Update the client treasure hunt info with the server info (ModData etc)
    clientTreasureHunt.ModData = newTreasureHunt.ModData
    clientTreasureHunt.RestrictMapForUser = newTreasureHunt.RestrictMapForUser -- This is for multplayer to restrict the map generation to this user.  If nil anyone can generate?
    clientTreasureHunt.RestrictMapForUserName = newTreasureHunt.RestrictMapForUserName

    -- check if a zombie needs hitting...
    RicksMLC_THSharedUtils.DumpArgs(clientTreasureHunt, 0, "Added clientTreasureHunt")
    self:CheckAndSetOnHitZombie(clientTreasureHunt)
end

function RicksMLC_TreasureHuntMgrClient:AddInitialTreasureHuntsFromServer(args)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient:AddInitialTreasureHuntsFromServer()")
    -- list of treasure hunt definitons and current status.
    for i, treasureHuntInfo in ipairs(args.treasureHuntList) do
        self:AddTreasureHuntFromServer(treasureHuntInfo)
    end
    RicksMLC_TreasureHuntMgr.Initialsed = true
end

function RicksMLC_TreasureHuntMgrClient.OnServerCommand(moduleName, command, args)
    -- Received a message from the server
	if moduleName ~= "RicksMLC_TreasureHuntMgrClient" then return end

    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient.OnServerCommand: " .. moduleName .. ", " .. command)
    if command == "AddTreasureHunt" then
        RicksMLC_TreasureHuntMgr.Instance():AddTreasureHuntFromServer(args.NewTreasureHunt)
        return
    end
    if command == "MapItemsGenerated" then
        -- Response from the server with the generated map item
        RicksMLC_TreasureHuntMgr.Instance():HandleOnMapItemsGenerated(args)
        return
    end
    if command == "SetOnHitZombieForNewMap" then
        if RicksMLC_TreasureHuntMgr.Instance().IsWaitingToHitZombie then return end
        -- FIXME: set for only the designated player
        RicksMLC_THSharedUtils.DumpArgs(args, 0, command .. " args")
        return
    end
    if command == "ServerResponseToOnHitZombie" then
        -- FIXME: do what now?
        return
    end
    if command == "InitialTreasureHunts" then
        RicksMLC_TreasureHuntMgr.Instance():AddInitialTreasureHuntsFromServer(args)
        return
    end
end

function RicksMLC_TreasureHuntMgrClient:RequestInitTreasureHunts()
    -- The pre-init trigger will cause 3rd party treasure maps to init for the client (defns etc)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient:RequestInitTreasureHunts()")
    triggerEvent("RicksMLC_TreasureHuntMgr_PreInit")
    local args = {}
    sendClientCommand(getPlayer(), "RicksMLC_TreasureHuntMgrServer", "RequestInitTreasureHunts", args)
end

function RicksMLC_TreasureHuntMgrClient:GetCachedTreasureHuntInfo(treasureHuntNum)
    return self.serverTreasureHuntsCache:GetCachedData(treasureHuntNum)
end

function RicksMLC_TreasureHuntMgrClient:GetAllCachedTreasureHuntInfo()
    return self.serverTreasureHuntsCache:GetCachedData()
end

function RicksMLC_TreasureHuntMgrClient:RefreshTreasureData()
    self.serverTreasureHuntsCache:ForceCacheUpdate()
end

function RicksMLC_TreasureHuntMgrClient:RefreshMgrServerStatus()
    self.serverMgrStatusCache:ForceCacheUpdate()
end

function RicksMLC_TreasureHuntMgrClient.OnConnected()
    local msg = "RicksMLC_TreasureHuntMgrClient.OnConnected() Player# "
    if getPlayer() then
        msg = msg .. tostring(getPlayer():getPlayerNum())
    else
        msg = msg .. "nil"
    end
    DebugLog.log(DebugType.Mod, msg)

    -- Does the initial synch happen here or OnGameStart?
    --sendClientCommand(getPlayer(), "RicksMLC_TreasureHuntMgrClient", "RequestTreasureHuntsInfo", {})
    RicksMLC_TreasureHuntMgr.Instance().serverTreasureHuntsCache:ForceCacheUpdate()
    RicksMLC_TreasureHuntMgr.Instance().serverMgrStatusCache:ForceCacheUpdate()
end

-- function RicksMLC_TreasureHuntMgrClient.OnCoopServerMessage(messageType, playerNick, steamId)
--     local msg = "OnCoopServerMessage: " .. messageType .. ": "
--     if getPlayer() then
--         msg = msg .. tostring(getPlayer():getPlayerNum()) .. " steamId: " .. tostring(getPlayer():getSteamID())
--     else
--         msg = msg .. "nil"
--     end
--     DebugLog.log(DebugType.Mod, msg)
--     if messageType ~= "steam-id" then return end
--
--     if getPlayer() and getPlayer():getSteamID() == steamId then
--         DebugLog.log(DebugType.Mod, "     steamId match - ReqestInitTreasureHunts")
--         RicksMLC_TreasureHuntMgr.Instance():RequestInitTreasureHunts()
--         -- Only subscribe to this message once to get the treasure hunts...
--         Events.OnCoopServerMessage.Remove(RicksMLC_TreasureHuntMgrClient.OnCoopServerMessage)
--     end
-- end

function RicksMLC_TreasureHuntMgrClient.OnDisconnect()
    Events.OnCoopServerMessage.Remove(RicksMLC_TreasureHuntMgrClient.OnCoopServerMessage)
    Events.OnCoopServerMessage.Add(RicksMLC_TreasureHuntMgrClient.OnCoopServerMessage)    
end

local function TreasureHuntMgrInitDone()
    DebugLog.log(DebugType.Mod, "client RicksMLC_TreasureHuntMgr_InitDone event detected")
end

local function TreasureHuntMgrPreInit()
    DebugLog.log(DebugType.Mod, "client RicksMLC_TreasureHuntMgr_PreInit event detected")
end

function RicksMLC_TreasureHuntMgrClient.OnGameStart()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient.OnGameStart start")
    Events.EveryOneMinute.Add(RicksMLC_TreasureHuntMgrClient.EveryOneMinuteAtStart)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr.OnGameStart end")
end

local startCount = 0
function RicksMLC_TreasureHuntMgrClient.EveryOneMinuteAtStart()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient.EveryOneMinuteAtStart(): " .. tostring(startCount))
    startCount = startCount + 1
    if startCount < 10 then return end
    -- TODO: FIXME: This request may be sent and actioned by the server before the server has finished initialising.
    --      Therefore the server needs to record the request and set it into a pending queue which waits for the server init to be complete.
    -- if the server is adding a treasure hunt it needs to hold the requests/responses until the add is complete... this is going to lead
    -- to a timing queue issue with possible race conditions.
    -- REQUIERS HANDSHAKE before initialising.  Using the "startCount < 10" for now...
    RicksMLC_TreasureHuntMgr.Instance():RequestInitTreasureHunts()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient.EveryOneMinuteAtStart(): done" )
    Events.EveryOneMinute.Remove(RicksMLC_TreasureHuntMgrClient.EveryOneMinuteAtStart)
end

Events.OnGameStart.Add(RicksMLC_TreasureHuntMgrClient.OnGameStart)
Events.OnConnected.Add(RicksMLC_TreasureHuntMgrClient.OnConnected)
-- FIXME: Remove? Events.OnCoopServerMessage.Add(RicksMLC_TreasureHuntMgrClient.OnCoopServerMessage)
Events.OnDisconnect.Add(RicksMLC_TreasureHuntMgrClient.OnDisconnect)
Events.OnServerCommand.Add(RicksMLC_TreasureHuntMgrClient.OnServerCommand)

Events.RicksMLC_TreasureHuntMgr_InitDone.Add(TreasureHuntMgrInitDone)
Events.RicksMLC_TreasureHuntMgr_PreInit.Add(TreasureHuntMgrPreInit)


-- Use this for testing/prototyping only
-- FIXME: comment out
function RicksMLC_TreasureHuntMgrClient.OnKeyPressed(key)
    if key == Keyboard.KEY_F10 then
        RicksMLC_TreasureHuntMgr.Instance():RequestInitTreasureHunts()
    end
end
-- Commented out code - uncomment to make temp test
--Events.OnKeyPressed.Add(RicksMLC_TreasureHuntMgrClient.OnKeyPressed)
