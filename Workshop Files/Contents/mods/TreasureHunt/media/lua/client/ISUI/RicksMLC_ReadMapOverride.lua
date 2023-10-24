-- RicksMLC_ReadMapOverride.lua
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

