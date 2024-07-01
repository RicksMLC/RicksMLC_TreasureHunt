-- Rick's MLC Treasure Hunt Client
--
-- Note: https://pzwiki.net/wiki/Category:Lua_Events

----------------------------------------------------------

require "Map/CGlobalObjectSystem"

RicksMLC_TreasureHuntSystemC = CGlobalObjectSystem:derive("RicksMLC_TreasureHuntSystemC")

function RicksMLC_TreasureHuntSystemC:new()
	local o = CGlobalObjectSystem.new(self, "RicksMLC_treasureHunt")
	if not o.treasureHuntMgr then error "RicksMLC_TreasureHuntSystemC:new() treasureHuntMgr wasn't sent from the server?" end

    return o
end

--DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntSystemC RegisterSystemClass")
CGlobalObjectSystem.RegisterSystemClass(RicksMLC_TreasureHuntSystemC)




function RicksMLC_TreasureHuntSystemC:OnServerCommand(command, args)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntSystemC:OnServerCommand: " .. command)

    if command == "MapItemsGenerated" then
        -- Response from the server with the generated map item
        self:HandleOnMapItemsGenerated(args)
        return
    end
    -- if command == "HandleNewTreasureHunt" then
	-- 	self.zombieSpawnList = args.zombieSpawnList
    --     return
    -- end
    if command == "AddTreasureHunt" then
        self:AddTreasureHuntFromServer(args)
        return
    end

    -- Call the base class
    CGlobalObjectSystem.OnServerCommand(self, command, args)
end
