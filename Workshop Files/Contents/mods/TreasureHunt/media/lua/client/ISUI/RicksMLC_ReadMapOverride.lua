-- RicksMLC_ReadMapOverride.lua
require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/Maps/ISMap"
require "RicksMLC_TreasureHunt"

local overideOnCheckMap = ISInventoryPaneContextMenu.onCheckMap
ISInventoryPaneContextMenu.onCheckMap = function(self, map, player)
    RicksMLC_TreasureHunt.SetReadingMap(map)
    overideOnCheckMap(self, map, player)
end

local overrideOnClose = ISMapWrapper.close
ISMapWrapper.close = function(self)
    RicksMLC_TreasureHunt.SetReadingMap(nil)
    overrideOnClose(self)
end

