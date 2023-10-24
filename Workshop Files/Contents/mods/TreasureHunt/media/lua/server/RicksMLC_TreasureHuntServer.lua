-- RicksMLC_TreasureHuntServer.lua

if not isServer() then return end
if isClient() then return end

------------------------------------------------------------------------

require "Map/SGlobalObjectSystem"

RicksMLC_TreasureHuntS = SGlobalObjectSystem:derive("RicksMLC_TreasureHuntS")
function RicksMLC_TreasureHuntS:new()
 	local o = SGlobalObjectSystem.new(self, "RicksMLC_TreasureHunt")

    -- Declare the global client/server shared information here.
    o.zombieSpawnList = { }
    o.numTrackedZombies = 0
    --o.dogTagDisplayName = InventoryItemFactory.CreateItem("Necklace_DogTag"):getDisplayName()

 	return o
end

SGlobalObjectSystem.RegisterSystemClass(RicksMLC_TreasureHuntS)

function RicksMLC_TreasureHuntS:isValidIsoObject(isoObject)
	return false
end

function SGlobalObjectSystem:newLuaObject(globalObject)
	-- Return an object derived from SGlobalObject
	return nil
end

function RicksMLC_TreasureHuntS:initSystem()
	SGlobalObjectSystem.initSystem(self)

	-- Specify GlobalObjectSystem fields that should be saved.
	self.system:setModDataKeys({'zombieSpawnList', 'numTrackedZombies', 'safehouseSafeZoneRadius'})
end

function RicksMLC_TreasureHuntS:getInitialStateForClient()
	-- Return a Lua table that is used to initialize the client-side system.
	-- This is called when a client connects in multiplayer, and after
	-- server-side systems are created in singleplayer.
	return { 
        zombieSpawnList = self.zombieSpawnList,
        numTrackedZombies = self.numTrackedZombies,
        safehouseSafeZoneRadius = self.safehouseSafeZoneRadius
    }
end


local RicksMLC_Commands = {}
RicksMLC_Commands.TreasureHunt = {}

function RicksMLC_Commands.TreasureHunt.AddTreasureHunt(player, args)
    DebugLog.log(DebugType.Mod, "RicksMLC_Commands.TreasureHunt.AddTreasureHunt()")
end

function RicksMLC_TreasureHuntS.OnClientCommand(moduleName, command, player, args)
    -- Receive a message from a client
    --DebugLog.log(DebugType.Mod, 'RicksMLC_SpawnServer.OnClientCommand() ' .. moduleName .. "." .. command)
    if RicksMLC_Commands[moduleName] and RicksMLC_Commands[moduleName][command] then
        -- FIXME: Comment out when done?
        -- local argStr = ''
 		-- for k,v in pairs(args) do argStr = argStr..' '..k..'='..tostring(v) end
 		-- DebugLog.log(DebugType.Mod, 'received '..moduleName..' '..command..' '..tostring(player)..argStr)
 		RicksMLC_Commands[moduleName][command](player, args)
    end
end

Events.OnClientCommand.Add(RicksMLC_TreasureHuntS.OnClientCommand)