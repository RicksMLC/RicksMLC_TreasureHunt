-- RicksMLC_TreasureHuntMgr.lua

require "ISBaseObject"
require "RicksMLC_TreasureHunt"

RicksMLC_TreasureHuntMgr = ISBaseObject:derive("RicksMLC_TreasureHuntMgr");

RicksMLC_TreasureHuntMgrInstance = nil

function RicksMLC_TreasureHuntMgr.Instance()
    if not RicksMLC_TreasureHuntMgrInstance then
        RicksMLC_TreasureHuntMgrInstance = RicksMLC_TreasureHuntMgr:new()
    end
    return RicksMLC_TreasureHuntMgrInstance
end

function RicksMLC_TreasureHuntMgr:new()
	local o = {}
	setmetatable(o, self)
	self.__index = self

    o.Initialised = false

    -- FIXME: Temporary treasure definitions for the RicksMLC_TreasureHunt_Distributions.lua
    o.Treasures = {
            "BorisBadger",
            "FluffyfootBunny",
            "FreddyFox",
            "FurbertSquirrel",
            "JacquesBeaver",
            "MoleyMole",
            "PancakeHedgehog",
            "Spiffo",
            "SpiffoBig",
            "ElectronicsMag4"
        }
    
    -- Treasure Hunt Definitions: { Name = string, Barricades = {min, max} | n, Zombies = {min, max} | n, Treasures = {string, string...}, Town = nil | string) }
    o.TreasureHuntDefinitions = {
        -- {Name = "Spiffo And Friends", Town = nil, Barricades = {1, 100}, Zombies = {3, 15}, Treasures = {
        --     "BorisBadger",
        --     "FluffyfootBunny",
        --     "FreddyFox",
        --     "FurbertSquirrel",
        --     "JacquesBeaver",
        --     "MoleyMole",
        --     "PancakeHedgehog",
        --     "Spiffo" }},
        {Name = "The Big Boss", Town = "SpecialCase", Barricades = {80, 100}, Zombies = {10, 15}, Treasures = {"SpiffoBig"}},
        {Name = "Maybe Helpful", Town = "FallusLake", Barricades = 90, Zombies = 30, Treasures = {"ElectronicsMag4"}} -- GenMag
    }

    o.TreasureHunts = {}

    o.ModData = nil
    return o
end

-------------------------------------------
-- SetReadingMap is the external static function called by the override for the Read Map menu item.
RicksMLC_MapIDLookup = ISBaseObject:derive("RicksMLC_MapIDLookup");

RicksMLC_MapIDLookupInstance = nil

function RicksMLC_MapIDLookup.Instance()
    if not RicksMLC_MapIDLookupInstance then
        RicksMLC_MapIDLookupInstance = RicksMLC_MapIDLookup:new()
    end
    return RicksMLC_MapIDLookupInstance
end

function RicksMLC_MapIDLookup:new()
	local o = {}
	setmetatable(o, self)
	self.__index = self

    o.readingMapId = nil
    o.Lookup = {}

    return o
end

function RicksMLC_MapIDLookup:AddMapID(mapId, huntId, mapNum)
    self.Lookup[mapId] = {HuntId = huntId, MapNum = mapNum}
end

--function RicksMLC_TreasureHunt.SetReadingMap(item) RicksMLC_TreasureHunt.Instance().readingMapID = item end
function RicksMLC_MapIDLookup:SetReadingMap(item) self.readingMapID = item end
function RicksMLC_MapIDLookup:GetReadingMap() return self.Lookup[self.readingMapID] end

-----------------------------------------
function RicksMLC_TreasureHuntMgr:GetMapPath()
    local mapLookup = RicksMLC_MapIDLookup.Instance():GetReadingMap()
    if not mapLookup then
        return RicksMLC_MapUtils.GetDefaultMapPath()
    end
    local mapPath = self.TreasureHunts[mapLookup.HuntId]:GetMapPath()
    return mapPath or RicksMLC_MapUtils.GetDefaultMapPath()
end

function RicksMLC_TreasureHuntMgr:setBoundsInSquares(mapAPI)
    local mapLookup = RicksMLC_MapIDLookup.Instance():GetReadingMap()
    if mapLookup then
        self.TreasureHunts[mapLookup.HuntId]:setBoundsInSquares(mapAPI, mapLookup.MapNum)
    end
end

function RicksMLC_TreasureHuntMgr:LoadModData()
    self.ModData = getGameTime():getModData()["RicksMLC_TreasureHuntMgr"]
    return self.ModData
end

function RicksMLC_TreasureHuntMgr:SaveModData()
    getGameTime():getModData()["RicksMLC_TreasureHuntMgr"] = self.ModData
end

-- Treasure Hunt Definitions: { Name = string, Barricades = {min, max} | n, Zombies = {min, max} | n, Treasures = {string, string...}, Town = nil | string) }
function RicksMLC_TreasureHuntMgr:AddTreasureHunt(treasureHuntDefn, addMapToZombie)
    self.TreasureHunts[#self.TreasureHunts+1] = RicksMLC_TreasureHunt:new(treasureHuntDefn, #self.TreasureHunts+1)
    self.TreasureHunts[#self.TreasureHunts]:InitTreasureHunt()
    self.TreasureHunts[#self.TreasureHunts]:ResetCurrentMapNum()
    --if addMapToZombie then
        RicksMLC_TreasureHuntMgr.HandleIfTreasureFound()
    --end
end

function RicksMLC_TreasureHuntMgr:InitTreasureHunts()
    if self:LoadModData() == nil then
        for i, treasureHuntDefn in ipairs(self.TreasureHuntDefinitions) do
            self:AddTreasureHunt(treasureHuntDefn, false)
            --self:SaveModData()
        end
    end
    --self:ResetAllCurrentHuntMapNums()
end

function RicksMLC_TreasureHuntMgr:ResetAllCurrentHuntMapNums()
    for i, treasureHunt in ipairs(self.TreasureHunts) do
       treasureHunt:ResetCurrentMapNum()
    end
end

------------------------------------------------------------
-- Static methods

function RicksMLC_TreasureHuntMgr.OnHitZombie(zombie, character, bodyPartType, handWeapon)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr.OnHitZombie()")
    -- Make sure it's not just any character that hits the zombie

    if character == getPlayer() then
        for i, treasureHunt in ipairs(RicksMLC_TreasureHuntMgr.Instance().TreasureHunts) do
            treasureHunt:HandleOnHitZombie(zombie, character, bodyPartType, handWeapon)
        end
        Events.OnHitZombie.Remove(RicksMLC_TreasureHuntMgr.OnHitZombie)
    end
end

function RicksMLC_TreasureHuntMgr.HandleIfTreasureFound()
    local needNewMap = false
    for i, treasureHunt in ipairs(RicksMLC_TreasureHuntMgr.Instance().TreasureHunts) do
        needNewMap = treasureHunt:CheckIfNewMapNeeded() or needNewMap
    end
    if needNewMap then 
        RicksMLC_TreasureHuntMgr.SetOnHitZombieForNewMap()
    end
end

function RicksMLC_TreasureHuntMgr.SetOnHitZombieForNewMap()
    Events.OnHitZombie.Remove(RicksMLC_TreasureHuntMgr.OnHitZombie)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr.SetOnHitZombieForNewMap() Waiting to hit a zombie")
    Events.OnHitZombie.Add(RicksMLC_TreasureHuntMgr.OnHitZombie)
end

function RicksMLC_TreasureHuntMgr.OnGameStart()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr.OnGameStart start")
    Events.EveryOneMinute.Add(RicksMLC_TreasureHuntMgr.EveryOneMinuteAtStart)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr.OnGameStart end")
end

local startCount = 0
function RicksMLC_TreasureHuntMgr.EveryOneMinuteAtStart()
    startCount = startCount + 1
    if startCount < 2 then return end
    RicksMLC_TreasureHuntMgr.Instance():InitTreasureHunts()
    RicksMLC_TreasureHuntMgr.HandleIfTreasureFound()
    RicksMLC_TreasureHuntMgr.Initialsed = true
    Events.EveryOneMinute.Remove(RicksMLC_TreasureHuntMgr.EveryOneMinuteAtStart)
end

function RicksMLC_TreasureHuntMgr.OnCreatePlayer(playerIndex, player)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr.OnCreatePlayer start " .. tostring(playerIndex))
    if RicksMLC_TreasureHuntMgr.Instance().Initialised then
        --RicksMLC_TreasureHunt.Instance().ModData.CurrentMapNum = 0
        RicksMLC_TreasureHuntMgr.Instance():ResetAllCurrentHuntMapNums()
    end
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr.OnCreatePlayer end")
end

function RicksMLC_TreasureHuntMgr.OnKeyPressed(key)
    if key == Keyboard.KEY_F10 then
        -- FIXME: Remove when testing Init is complete
        --RicksMLC_TreasureHuntMgr.Instance():InitTreasureHunts()
        --RicksMLC_TreasureHuntMgr.HandleTransferActionPerform()
    end
end

Events.OnKeyPressed.Add(RicksMLC_TreasureHuntMgr.OnKeyPressed)
Events.OnGameStart.Add(RicksMLC_TreasureHuntMgr.OnGameStart)
Events.OnCreatePlayer.Add(RicksMLC_TreasureHuntMgr.OnCreatePlayer)