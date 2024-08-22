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
    return RicksMLC_TreasureHunt.GenerateNextMapItem(self, false) -- Don't doStash on the server, as the client will do it when the map is read.
end

function RicksMLC_TreasureHuntServer:UpdateLootMapsInitFn(stashMapName, huntId, i)
    -- The LootMaps table does not exist on the server. This override masks it out.
end

function RicksMLC_TreasureHuntServer:AddMapToWorld(mapItem, zombie, gridSquare)
    -- Maps can only be added to the world on the client, so override to mask out.
end

-- FIXME: This is a workaround which may have to remain for the server side.
function RicksMLC_TreasureHuntServer:HandleClientOnHitZombie(player, character)
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
        mapItemDetails = self:AddNextMapToZombie(nil, true, nil)

        self.ModData.LastSpawnedMapNum = self.ModData.CurrentMapNum
        self:SaveModData()
    end
    return mapItemDetails
end