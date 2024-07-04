-- RicksMLC_TreasureHuntMgrClient.lua
--
-- Client side treasure hunt manager for MP
-- Inherits from the shared treasure hunt manager, and facilitates the client/server comms from the client side.
--
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

    Events.OnServerCommand.Add(function(moduleName, command, args) RicksMLC_TreasureHuntMgrClient.Instance().serverTreasureHuntsCache:OnServerCommand(moduleName, command, args) end)

    return o
end

function RicksMLC_Cache:OnServerCommand(moduleName, command, args)
    DebugLog.log(DebugType.Mod, "RicksMLC_Cache:OnServerCommand '" .. command .. "' playerNum: " .. tostring(args.playerNum))
    if moduleName == "RicksMLC_Cache" then
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

function RicksMLC_TreasureHuntMgrClient:GetMgrStatusFromServer()
    local status = {text = "", error = nil}
    if self.serverMgrStatusCache then
        local cachedData = self.serverMgrStatusCache:GetCachedData()
        if cachedData.error then
            status.error = "Error: " .. cachedData.error
        else
            if cachedData.data.isWaitingToHitZombie then
                status.text = "Waiting to hit zombie"
            end
        end
    else
        status.error = "serverMgrStatusCache not found"
    end
    return status
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

function RicksMLC_TreasureHuntMgrClient:RecordFoundTreasure(huntId, foundMapNum)
    -- Inform the server the treasure hunt item has been found.
    local args = {huntId = huntId, mapNum = foundMapNum}
    sendClientCommand(getPlayer(), "RicksMLC_TreasureHuntMgrServer", "RecordFoundTreasure", args)
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
        RicksMLC_TreasureHuntMgrClient.Instance():AddTreasureHuntFromServer(args.NewTreasureHunt)
        return
    end
    if command == "MapItemsGenerated" then
        -- Response from the server with the generated map item
        RicksMLC_TreasureHuntMgrClient.Instance():HandleOnMapItemsGenerated(args)
        return
    end
    if command == "ServerResponseToOnHitZombie" then
        -- FIXME: do what now?
        return
    end
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


function RicksMLC_TreasureHuntMgrClient.OnGameStart()
    local msg = "RicksMLC_TreasureHuntMgrClient.OnGameStart() Player# "
    if getPlayer() then
        msg = msg .. tostring(getPlayer():getPlayerNum())
    else
        msg = msg .. "nil"
    end
    DebugLog.log(DebugType.Mod, msg)
    RicksMLC_TreasureHuntMgr.Instance()
    triggerEvent("RicksMLC_TreasureHuntMgr_PreInit")
    -- TODO: Initialise the connection to the treasure hunt manager server side
--    RicksMLC_TreasureHuntMgr.Instance().serverTreasureHuntsCache:ForceCacheUpdate()
--    RicksMLC_TreasureHuntMgr.Instance().serverMgrStatusCache:ForceCacheUpdate()
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
Events.OnConnected.Add(RicksMLC_TreasureHuntMgrClient.OnConnected)

Events.OnServerCommand.Add(RicksMLC_TreasureHuntMgrClient.OnServerCommand)

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