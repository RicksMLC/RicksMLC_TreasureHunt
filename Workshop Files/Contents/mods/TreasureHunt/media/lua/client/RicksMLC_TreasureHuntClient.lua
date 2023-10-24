-- Rick's MLC Treasure Hunt Client
--
-- Note: https://pzwiki.net/wiki/Category:Lua_Events

----------------------------------------------------------

require "Map/CGlobalObjectSystem"

RicksMLC_TreasureHuntC = CGlobalObjectSystem:derive("RicksMLC_TreasureHuntC")

function RicksMLC_TreasureHuntC:new()
	local o = CGlobalObjectSystem.new(self, "RicksMLC_TreasureHunt")
	-- if not o.zombieSpawnList then error "zombieSpawnList wasn't sent from the server?" end
    -- if not o.numTrackedZombies then error "numTrackedZombies wasn't sent from the server?" end
    -- if not o.safehouseSafeZoneRadius then error "safehouseSafeZoneRadius wasn't sent from the server?" end

	return o
end

-- Process the command from the server
function RicksMLC_TreasureHuntC:OnServerCommand(command, args)
	-- if command == "HandleSpawnedZombies" then
	-- 	self.zombieSpawnList = args.zombieSpawnList
    --     self.numTrackedZombies = args.numTrackedZombies
    -- elseif command == "UpdateSafehouseZone" then
    --     self.safehouseSafeZoneRadius = args.safehouseSafeZoneRadius
    -- else
		CGlobalObjectSystem.OnServerCommand(self, command, args)
	-- end
end

if isClient() then
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntC. RegisterSystemClass")
    CGlobalObjectSystem.RegisterSystemClass(RicksMLC_TreasureHuntC)
end

-----------------------------------------------
-- RicksMLC_SpawnHandler is the client-side of the server spawn.
-- This class receives messages from the server with the list of 
-- spawned zombies, which is uses to set the zombie dogtags when the client hits them.
-- require "ISBaseObject"
-- RicksMLC_TreasureHunt = ISBaseObject:derive("RicksMLC_TreasureHunt")

-- RicksMLC_SpawnHandlerInstance = nil
-- function RicksMLC_SpawnHandler.Instance()
--     if not RicksMLC_SpawnHandlerInstance then
--         RicksMLC_SpawnHandlerInstance = RicksMLC_SpawnHandler:new()
--     end
--     return RicksMLC_SpawnHandlerInstance
-- end

-- function RicksMLC_SpawnHandler:new()
--     local o = {}
--     setmetatable(o, self)
--     self.__index = self

--     o.spawnedZombies = {}
--     o.numTrackedZombies = 0

--     o.isOnHitZombieOn = false

--     return o
-- end
