-- RicksMLC_TreasureHuntClient.lua
-- Client version of the base RicksMLC_TreasureHunt class

require "RicksMLC_TreasureHunt"
RicksMLC_TreasureHuntClient = RicksMLC_TreasureHuntSharedMP:derive("RicksMLC_TreasureHuntClient")

function RicksMLC_TreasureHuntClient:new(treasureHuntDefn, huntId)
    local o = RicksMLC_TreasureHuntSharedMP:new(treasureHuntDefn, huntId)
    setmetatable(o, self)
    self.__index = self

    return o
end

function RicksMLC_TreasureHuntClient:UpdateTreasureHuntMap(mapItemDetails)
    --DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient:UpdateTreasureHuntMap()")
    self.ModData.Maps = mapItemDetails.Maps
    self.ModData.LastSpawnedMapNum = self.ModData.CurrentMapNum
    self:AddStashFromServer()
    self:UpdateLootMapsInitFn(mapItemDetails.stashMapName, mapItemDetails.huntId, mapItemDetails.i)
end

function RicksMLC_TreasureHuntClient:AddStashFromServer()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntClient:AddStashFromServer()")
    local stashMapName = self.ModData.Maps[self.ModData.CurrentMapNum].stashMapName
    local stashDesc = RicksMLC_StashDescLookup.Instance():StashLookup(stashMapName)
    if not stashDesc then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntClient:AddStashFromServer() Adding stash for " .. stashMapName)
        self:AddStashToStashUtil(self.ModData.Maps[self.ModData.CurrentMapNum], self.ModData.CurrentMapNum, stashMapName)
        -- The reinit is necessary when adding a stash after the game is started.
        -- If the StashSystem is not reinitialised the StashSystem.getStash() not find the stash, even if the
        -- stash name is in the StashSystem.getPossibleStashes():get(i):getName()
        StashSystem.reinit()
    else
        DebugLog.log(DebugType.Mod, "  Found existing stash for " .. stashMapName)
        RicksMLC_THSharedUtils.DumpArgs(stashDesc, 0, "Existing Stash Details")
    end
end