-- Override the ISWorldMap:getStashMapBounds() and ISWorldMap:onMouseUpStashMap() to remember the "current" map name for the ISWorldMap trying to get the bounds.
-- This only works because the lua code is single-threaded.

require "ISUI/Maps/ISWorldMap"
RicksMLC_ISWorldMapOverride = {}
RicksMLC_ISWorldMapOverride.currentStashMapNameForISWorldMap = nil

local old_getStashMapBounds = ISWorldMap.getStashMapBounds
function ISWorldMap:getStashMapBounds(stashName)
    RicksMLC_ISWorldMapOverride.currentStashMapNameForISWorldMap = stashName
    local retValue = old_getStashMapBounds(self, stashName)
    RicksMLC_ISWorldMapOverride.currentStashMapNameForISWorldMap = nil
    return retValue
end

-- This is needed for the display of the stash map on the world map when the player clicks on the stash icon.
local old_mouseUpStashMap = ISWorldMap.onMouseUpStashMap
function ISWorldMap:onMouseUpStashMap()
    if not self.mouseOverStashMap then return old_mouseUpStashMap(self) end
    RicksMLC_ISWorldMapOverride.currentStashMapNameForISWorldMap = self.mouseOverStashMap.stashName
    local retValue = old_mouseUpStashMap(self)
    RicksMLC_ISWorldMapOverride.currentStashMapNameForISWorldMap = nil
    return retValue
end
