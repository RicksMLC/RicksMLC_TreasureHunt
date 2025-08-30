-- RicksMLC_TreasureHuntClient.lua
-- Client version of the base RicksMLC_TreasureHunt class

require "RicksMLC_TreasureHunt"
RicksMLC_TreasureHuntClient = RicksMLC_TreasureHuntSharedMP:derive("RicksMLC_TreasureHuntClient")

LuaEventManager.AddEvent("RicksMLC_TreasureHuntClient_Finished")

function RicksMLC_TreasureHuntClient:new(treasureHuntDefn, huntId)
    local o = RicksMLC_TreasureHuntSharedMP:new(treasureHuntDefn, huntId)
    setmetatable(o, self)
    self.__index = self

    return o
end

function RicksMLC_TreasureHuntClient:UpdateTreasureHuntMap(mapItemDetails)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgrClient:UpdateTreasureHuntMap() self.CurrentMapNum: " .. tostring(self.ModData.CurrentMapNum) .. " mapItemDetails.i: " .. tostring(mapItemDetails.i))
    self.ModData.CurrentMapNum = mapItemDetails.i
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
        self:UpdateStashSystem()
    else
        DebugLog.log(DebugType.Mod, "  Found existing stash for " .. stashMapName)
        --RicksMLC_THSharedUtils.DumpArgs(stashDesc, 0, "Existing Stash Details")
    end
end

function RicksMLC_TreasureHuntClient:FinishHunt(bError, playerUsername)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntClient:FinishHunt() Player: " .. tostring(playerUsername))
    if not playerUsername or not self.TreasureHuntDefn.Player or self.TreasureHuntDefn.Player == getPlayer():getUsername() then 
        -- Dodgy hack: If there is no playerUsername then this client is the finder and username is not needed. So call the base method.
        RicksMLC_TreasureHunt.FinishHunt(self, bError)
        return
    end
    playerUsername = playerUsername or getPlayer():getUsername() -- Dodgy Hack cont'd: Assumes if no playerUsername then this is the client which is finishing the treasure hunt.
    self.ModData.Finished = true
    self.Finished = true
    self.FinishedBy = playerUsername
    self:SaveModData()
    if bError then
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntClient:FinishHunt() Finished in ERROR state - something went wrong.")
        return
    end
    triggerEvent("RicksMLC_TreasureHuntClient_Finished", self.TreasureHuntDefn, playerUsername)
end

function RicksMLC_TreasureHuntClient:IsValidAddNextMapToZombie(character)
    return RicksMLC_TreasureHunt.IsValidAddNextMapToZombie(self, character)
       and self:IsCorrectPlayer(getPlayer())
end
