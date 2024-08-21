-- RicksMLC_TreasureHuntSharedMP.lua
-- Commom MP code for a TreasureHunt for the base RicksMLC_TreasureHunt class

require "RicksMLC_TreasureHunt"
RicksMLC_TreasureHuntSharedMP = RicksMLC_TreasureHunt:derive("RicksMLC_TreasureHuntSharedMP")

function RicksMLC_TreasureHuntSharedMP:new(treasureHuntDefn, huntId)
    local o = RicksMLC_TreasureHunt:new(treasureHuntDefn, huntId)
    setmetatable(o, self)
    self.__index = self

    o.RestrictMapForUser = nil -- This is for multplayer to restrict the map generation to this user.  If nil anyone can generate?
    o.RestrictMapForUserName = nil

    return o
end

function RicksMLC_TreasureHuntSharedMP:GetCurrentTreasureHuntInfo()
    local info = RicksMLC_TreasureHunt.GetCurrentTreasureHuntInfo(self)
    if info then
        info.RestrictMapForUserName = self.RestrictMapForUserName
    end
    return info
end

function RicksMLC_TreasureHuntSharedMP:SaveModData()
    self.ModData.RestrictMapForUser = self.RestrictMapForUser
    self.ModData.RestrictMapForUserName = self.RestrictMapForUserName
    RicksMLC_TreasureHunt.SaveModData(self)
end

function RicksMLC_TreasureHuntSharedMP:LoadModData()
    RicksMLC_TreasureHunt.LoadModData(self)
    self.RestrictMapForUser = self.ModData.RestrictMapForUser
    self.RestrictMapForUserName = self.ModData.RestrictMapForUserName
end

-- MP: Id a player
function RicksMLC_TreasureHuntSharedMP:GetPlayerId(player)
    return player:getSteamID()
end

-- MP: Limits the creation of the maps to this player.
function RicksMLC_TreasureHuntSharedMP:RestrictMapToPlayer(player)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntSharedMP:RestrictMapToPlayer() " .. player:getUsername())
    self.RestrictMapForUser = self:GetPlayerId(player)
    self.RestrictMapForUserName = player:getUsername()
end

-- MP: Releases the map so any player will get it.
function RicksMLC_TreasureHuntSharedMP:UnrestrictMapForPlayers()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntSharedMP:RestrictMapToPlayer() " .. tostring(self.RestrictMapForUserName))
    self.RestrictMapForUser = nil
    self.RestrictMapForUserName = nil
end

function RicksMLC_TreasureHuntSharedMP:IsValidAddNextMapToZombie(character)
    return RicksMLC_TreasureHunt.IsValidAddNextMapToZombie(self, character)
       and (not self.RestrictMapForUser or self.RestrictMapForUser == self:GetPlayerId(getPlayer()))
end
