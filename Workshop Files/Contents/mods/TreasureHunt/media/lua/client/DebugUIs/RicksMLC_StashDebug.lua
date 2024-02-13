-- RicksMLC_StashDebug.lua
-- Overrides the vanilla StashDebug.onClick so it does not crash when the user clicks on a TreasureHunt stash.

require "DebugUIs/StashDebug"
require "RicksMLC_TreasureHuntMgr"

local overrideStashDebugOnClick = StashDebug.onClick

StashDebug.onClick = function(self, button)
    if button.internal ~= "SPAWN" then
        overrideStashDebugOnClick(self, button)
        return
    end
    if self.selectedStash then
        -- The code reflects the function RicksMLC_TreasureHunt:GenerateNextMap() code.
        -- It uses the self.selectedStash:getItem() to detect it is a RicksMLC_TreasureHunt_ map, 
        -- and use the rest of the string up to the "(" to get the name to match.
        local itemName = self.selectedStash:getItem()
        local tmString = "RicksMLC_TreasureMap"
        local map = nil
        local i, j = itemName:find(tmString)
        if i then
            local str = itemName:sub(j+1)
            local treasureHuntName = string.match(itemName, "_([^_]+)_", j + 1)
            if not treasureHuntName then
                DebugLog.log(DebugType.Mod, "RicksMLC_StashDebug: Unable to determine the Name of the treasure hunt for item '" .. itemName .. "'")
                return
            end
            map = RicksMLC_TreasureHuntMgr.Instance():GetMapFromTreasureHunt(treasureHuntName)
            if not map then 
                DebugLog.log(DebugType.Mod, "RicksMLC_StashDebug: Unable to get the map for the treasure hunt '" .. treasureHuntName .. "'")
                return
            end
        else
            map = InventoryItemFactory.CreateItem(itemName);
        end
        StashSystem.doStashItem(self.selectedStash, map);
        getPlayer():getInventory():AddItem(map);
        local mapUI = ISMap:new(0, 0, 0, 0, map, 0);
        map:doBuildingStash();
        if not i then
            -- only use auto teleportation to the map location for non-RicksMLC_TreasureHunt maps.
            getPlayer():setX(self.selectedStash:getBuildingX() + 20);
            getPlayer():setY(self.selectedStash:getBuildingY() + 20);
            getPlayer():setLx(self.selectedStash:getBuildingX() + 20);
            getPlayer():setLy(self.selectedStash:getBuildingY() + 20);
            getPlayer():setZ(0)
        end
        self:populateList();
    end
end

