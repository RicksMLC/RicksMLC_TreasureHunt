-- RicksMLC_TreasureHuntServer.lua

------------------------------------------------------------------------

if isClient() then return end

require "Map/SGlobalObjectSystem"
require "RicksMLC_TreasureHuntMgrServer"

RicksMLC_TreasureHuntSystemS = SGlobalObjectSystem:derive("RicksMLC_TreasureHuntSystemS")
function RicksMLC_TreasureHuntSystemS:new()
 	local o = SGlobalObjectSystem.new(self, "RicksMLC_treasureHunt")

    -- Declare the global client/server shared information here.
    -- FIXME: Remove: o.treasureHuntMgr = { }
 	return o
end

SGlobalObjectSystem.RegisterSystemClass(RicksMLC_TreasureHuntSystemS)

function RicksMLC_TreasureHuntSystemS:isValidIsoObject(isoObject)
	-- Adding a new TreasureHunt?  Is a TreasureHunt a GlobalSystemObject?
	return false
end

function RicksMLC_TreasureHuntSystemS:newLuaObject(globalObject)
	-- Return an object derived from SGlobalObject
	-- Adding a new TreasureHunt?  Make TreasureHunt a GlobalSystemObject?
	return nil
end

function RicksMLC_TreasureHuntSystemS:initSystem()
	SGlobalObjectSystem.initSystem(self)

	-- Specify GlobalObjectSystem fields that should be saved.
	self.system:setModDataKeys({'treasureHuntMgr'})

	-- Specify GlobalObject fields that should be saved.
	--example from campfire: self.system:setObjectModDataKeys({'exterior', 'isLit', 'fuelAmt'})
end

function RicksMLC_TreasureHuntSystemS:getInitialStateForClient()
	-- Return a Lua table that is used to initialize the client-side system.
	-- This is called when a client connects in multiplayer, and after
	-- server-side systems are created in singleplayer.
	return { 
        treasureHuntMgr = self.treasureHuntMgr
    }
end

function RicksMLC_TreasureHuntSystemS:HandleClientOnHitZombie(player, args)
    -- Server has received a message that the client has hit a zombie
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntS:HandleClientOnHitZombie()")
    local mapItemList = self.treasureHuntMgr:CreateClientInitiatedMapItems(player, args)
    local replyArgs = {playerNum = player:getPlayerNum(), mapItemList = mapItemList, treasureHuntMgr = self.treasureHuntMgr}
    RicksMLC_THSharedUtils.DumpArgs(replyArgs, 0, "RicksMLC_TreasureHuntS:HandleClientOnHitZombie() replyArgs")
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntS:HandleClientOnHitZombie()")
    sendCommand("MapItemsGenerated", replyArgs)
end


function RicksMLC_TreasureHuntSystemS:OnClientCommand(command, player, args)
    -- Receive a message from a client
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntS.OnClientCommand() '" .. command .. "'")
	if command == "ClientOnHitZombie" then
        self.HandleClientOnHitZombie(player, args)
    end
end

--Events.OnClientCommand.Add(RicksMLC_TreasureHuntS.OnClientCommand)