-- RicksMLC_TreasureHuntServer.lua
-- Server version of the base RicksMLC_TreasureHunt class

require "RicksMLC_TreasureHunt"
RicksMLC_TreasureHuntServer = RicksMLC_TreasureHuntSharedMP:derive("RicksMLC_TreasureHuntServer")

function RicksMLC_TreasureHuntServer:new(treasureHuntDefn, huntId)
    local o = RicksMLC_TreasureHuntSharedMP:new(treasureHuntDefn, huntId)
    setmetatable(o, self)
    self.__index = self

    return o
end

function RicksMLC_TreasureHuntServer:GenerateNextMapItem(doStash)
    -- FIXME: changed the doStash to true.
    return RicksMLC_TreasureHunt.GenerateNextMapItem(self, true) -- Don't doStash on the server, as the client will do it when the map is read.
end

function RicksMLC_TreasureHuntServer:UpdateLootMapsInitFn(stashMapName, huntId, i)
    -- The LootMaps table does not exist on the server. This override masks it out.
end

-- FIXME: Remove as the server must do these things to items.
--function RicksMLC_TreasureHuntServer:AddMapToWorld(mapItem, zombie, gridSquare)
    -- Maps can only be added to the world on the client, so override to mask out.
    -- FIXME: From B42 objects are created on the server.  So this should not mask out the AddMapToWorld() on the server, but should be implemented to add the mapItem to the world on the server.
--end

-- FIXME: Remove the masking of CallDecorator() as an experiment.  
-- Annotations are not visible on the map in MP but are in SP.  So are the map annotations reqired on the server
-- so they are visible on the client?
--function RicksMLC_TreasureHuntServer:CallDecorator(stashMap, treasureModData, i)
    -- The TreasureHunt CallDecorator() does nothing on the server.  Mask out.
    -- This may need to change when the decorations are stored on the mapItem, and need to be
    -- propagated to all of the clients.
    -- The reason for masking is because the base CallDecorator() fails with the RicksMLC_AdHocCmds:ChatTreasure
    -- as the decorators in the chat integration are declared in the client, so are not visible on the server.
--end

-- FIXME: This is a workaround which may have to remain for the server side.
function RicksMLC_TreasureHuntServer:HandleClientOnHitZombie(player, zombie)
    -- Server side handling of a client hitting a zombie - generate the treasure map defn (distribtions etc)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntServer.HandleClientOnHitZombie() ".. self.Name)
    if self.ModData.Finished then return nil end

    local mapItemDetails = nil
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHunt.HandleClientOnHitZombie() CurrentMapNum: " .. tostring(self.ModData.CurrentMapNum) .. " LastSpawnedMapNum " .. tostring(self.ModData.LastSpawnedMapNum))
    if self.ModData.CurrentMapNum == 0 then
        -- FIXME: Should this really be incrementing as this is generating a new map anyway.
        self.ModData.CurrentMapNum = self.ModData.CurrentMapNum + 1
    end
    if self.ModData.CurrentMapNum ~= self.ModData.LastSpawnedMapNum then
        mapItemDetails = self:AddNextMapToZombie(zombie, true, nil)
        mapItemDetails = self:ApplyRestrictToPlayer(mapItemDetails)
        self.ModData.LastSpawnedMapNum = self.ModData.CurrentMapNum
        self:SaveModData()
    end
    return mapItemDetails
end