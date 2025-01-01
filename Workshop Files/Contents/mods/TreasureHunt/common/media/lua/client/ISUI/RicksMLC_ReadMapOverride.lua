-- RicksMLC_ReadMapOverride.lua
-- Overrides the onCheckMap function to record the mapId currently being read, so the TreasureHunt
-- can look up the correct map bounds to correspond with it in the LootMaps.Init[stashMapName]

require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/Maps/ISMap"
require "RicksMLC_TreasureHuntMgr"

local overideOnCheckMap = ISInventoryPaneContextMenu.onCheckMap
ISInventoryPaneContextMenu.onCheckMap = function(self, map, player)
    RicksMLC_MapIDLookup.Instance():SetReadingMap(self:getMapID())
    overideOnCheckMap(self, map, player)
end

local overrideOnClose = ISMapWrapper.close
ISMapWrapper.close = function(self)
    RicksMLC_MapIDLookup.Instance():SetReadingMap(nil)
    overrideOnClose(self)
end

