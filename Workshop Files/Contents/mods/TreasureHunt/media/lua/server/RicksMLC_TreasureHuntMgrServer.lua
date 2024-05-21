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
-- 3) 

if not isServer() or isClient() then return end

DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer: Server code used")

require "RicksMLC_TreasureHuntMgr"

RicksMLC_TreasureHuntMgrServer = RicksMLC_TreasureHuntMgr:derive("RicksMLC_TreasureHuntMgrServer");

-- Override the base class Instance()?
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

function RicksMLC_TreasureHuntMgrServer.SetOnHitZombieForNewMap()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer.SetOnHitZombieForNewMap() Server sending Waiting to hit a zombie")
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

function RicksMLC_TreasureHuntMgrServer:AddClientGeneratedTreasure(mapItemDetails)
    for i, treasureHunt in ipairs(self.TreasureHunts) do
        if treasureHunt.Name == mapItemDetails.Name then
        --    local treasureHunt = self.TreasureHunts[mapItemDetails.Index]
        --if treasureHunt then
            -- treasureHunt: self.ModData.Maps[i] = self:CreateTreasureModData(treasure, mapBounds) - assign this from the client-generated map
            RicksMLC_THSharedUtils.DumpArgs(treasureHunt, 0, "Existing Treasure Hunt")
            RicksMLC_THSharedUtils.DumpArgs(mapItemDetails, 0, "mapItemDetails")
            -- RicksMLC_TreasureHunt:AddStashMap(treasureModData, i)
            treasureHunt.ModData.LastSpawnedMapNum = mapItemDetails.i
            treasureHunt.ModData.Maps = mapItemDetails.Maps
            treasureHunt:AddStashMap(mapItemDetails.treasureModData, mapItemDetails.i)
            StashSystem.reinit() -- I think the reinit() is needed so the added stash is registered into the StashSystem othewise the getStash() does not find the stash
            --local mapItem = self:RecreateMapItem(mapItemDetails)
            local mapItem = mapItemDetails.mapItem
            local stash = StashSystem.getStash(mapItemDetails.stashMapName)
            if stash then
                StashSystem.doStashItem(stash, mapItem) -- Copies the stash.annotations to the java layer stash object and removes from potential stashes.
                DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer:AddClientGeneratedTreasure(): doStashItem() called for '" .. mapItem:getMapID() .. "'")
            else
                DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer:AddClientGeneratedTreasure() Error: No stash found in StashSystem.getStash('" .. mapItemDetails.stashMapName .. "')" )
            end
            treasureHunt:SaveModData()
        end
    end
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

    local mapItemList = self:CreateClientInitiatedMapItems(player, args)
    local replyArgs = {playerNum = player:getPlayerNum(), mapItemList = mapItemList}
    RicksMLC_THSharedUtils.DumpArgs(replyArgs, 0, "RicksMLC_TreasureHuntMgrServer:HandleClientOnHitZombie() replyArgs")
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer:HandleClientOnHitZombie()")
    sendServerCommand("RicksMLC_TreasureHuntMgrClient", "MapItemsGenerated", replyArgs)

    -- FIXME: Commented out to try generating all and returning to the client
    -- The args has generatedMapList which is a list of mapItemDetails:
    --      {mapItem = mapItem, stashMapName = mapItem:getMapID(), huntId = self.HuntId, i = self.ModData.CurrentMapNum}
    -- This list is incorporated back into the TreasureHuntMgr and sent to the other clients.
    -- if #args.generatedMapList > 0 then
    --     DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer:HandleClientOnHitZombie() mapItemList generated (" .. tostring(#args.generatedMapList) .. ")")
    --     local mapItemList = {}
    --     for _, mapItemDetails in ipairs(args.generatedMapList) do
    --         self:AddClientGeneratedTreasure(mapItemDetails)
    --     end
    --     local replyArgs = {playerNum = player:getPlayerNum(), mapItemList = mapItemList}
    --     sendServerCommand("RicksMLC_TreasureHuntMgrClient", "MapItemsGenerated", replyArgs)
    -- end

end

-------------------------------------
-- Static methdods

function RicksMLC_TreasureHuntMgrServer.OnClientCommand(moduleName, command, player, args)
    -- Receive a message from a client
    --DebugLog.log(DebugType.Mod, 'RicksMLC_SpawnServer.OnClientCommand() ' .. moduleName .. "." .. command)
    if moduleName ~= "RicksMLC_TreasureHuntMgrServer" then return end

    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer.OnClientCommand: " .. moduleName .. ", " .. command)
    if command == "ClientOnHitZombie" then
        RicksMLC_TreasureHuntMgr.Instance():HandleClientOnHitZombie(player, args)
    end
end

Events.OnClientCommand.Add(RicksMLC_TreasureHuntMgrServer.OnClientCommand)


function RicksMLC_TreasureHuntMgrServer.OnServerStarted()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrServer.OnServerStarted()")
    RicksMLC_TreasureHuntMgr.Instance()
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

