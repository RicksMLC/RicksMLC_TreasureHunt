-- RicksMLC_TreasureHuntTransferItemTA.lua
-- Override the ISInventoryTransferAction:transferItem(item) (or something) so I can detect placing the treasure into the player inventory.

require "TimedActions/ISInventoryTransferAction"
require "RicksMLC_TreasureHuntMgr"

local origTransferFn = ISInventoryTransferAction.perform
function ISInventoryTransferAction.perform(self)
    origTransferFn(self)

    -- Only check if adding to the charcter inventory.  We don't care about removing things from the character
    -- or transferring from one container to another (eg inventory -> backpack)
    if self.srcContainer == self.character:getInventory() or self.srcContainer:isInCharacterInventory(self.character) then
        return
    end
    -- Check if the destination container is the character
    if self.destContainer == self.character:getInventory() or self.destContainer:isInCharacterInventory(self.character) then
        RicksMLC_TreasureHuntMgr.HandleTransferItemPerform()
    end
end