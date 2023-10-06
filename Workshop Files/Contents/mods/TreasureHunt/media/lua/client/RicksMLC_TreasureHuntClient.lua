-- Rick's MLC Treasure Hunt
--
-- Note: https://pzwiki.net/wiki/Category:Lua_Events

require "ISBaseObject"

RicksMLC_TreasureHuntClient = ISBaseObject:derive("RicksMLC_TreasureHuntClient");

RicksMLC_TreasureHuntClientInstance = nil

function RicksMLC_TreasureHuntClient:new()
	local o = {}
	setmetatable(o, self)
	self.__index = self

    return o
end
