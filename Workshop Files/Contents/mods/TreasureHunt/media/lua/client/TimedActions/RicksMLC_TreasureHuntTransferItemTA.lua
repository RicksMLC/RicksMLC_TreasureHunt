-- RicksMLC_TreasureHuntTransferItemTA.lua
-- Override the ISInventoryTransferAction:transferItem(item) (or something) so I can detect placing the treasure into the player inventory.

require "TimedActions/ISInventoryTransferAction"
require "RicksMLC_TreasureHuntMgr"

local origTransferFn = ISInventoryTransferAction.perform
function ISInventoryTransferAction.perform(self)
    origTransferFn(self)

    RicksMLC_TreasureHuntMgr.HandleIfTreasureFound()
end