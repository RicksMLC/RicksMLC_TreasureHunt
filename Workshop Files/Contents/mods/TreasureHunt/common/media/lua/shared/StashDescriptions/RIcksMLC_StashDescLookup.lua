
-- RicksMLC_StashDescLookup.lua

require "ISBaseObject"

RicksMLC_StashDescLookup = ISBaseObject:derive("RicksMLC_StashDescLookup");

RicksMLC_StashDescLookupInstance = nil
function RicksMLC_StashDescLookup.Instance()
    if not RicksMLC_StashDescLookupInstance then
        RicksMLC_StashDescLookupInstance = RicksMLC_StashDescLookup:new()
    end
    return RicksMLC_StashDescLookupInstance
end

function RicksMLC_StashDescLookup:new()
	local o = {}
	setmetatable(o, self)
	self.__index = self

    o.stashLookup = {}
    for i, stashDesc in ipairs(StashDescriptions) do
        o.stashLookup[stashDesc.name] = stashDesc
    end

    return o
end

function RicksMLC_StashDescLookup:StashLookup(stashMapName)
    return self.stashLookup[stashMapName]
end

function RicksMLC_StashDescLookup:AddNewStash(name)
    self.stashLookup[name] = "foo"
end