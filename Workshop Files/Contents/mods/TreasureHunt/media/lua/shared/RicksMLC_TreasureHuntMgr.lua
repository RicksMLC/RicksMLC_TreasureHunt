-- RicksMLC_TreasureHuntMgr.lua
-- Treasure Hunt Definitions: { Name = string, Barricades = {min, max} | n, Zombies = {min, max} | n, Treasures = {string, string...}, Town = nil | string) }
-- Example:
    -- o.TreasureHuntDefinitions = {
    --     {Name = "Spiffo And Friends", Town = nil, Barricades = {1, 100}, Zombies = {3, 15},minTrapToSpawn = 1, DecoratorCallbackFn = callBackFn, Treasures = {
    --         "BorisBadger",
    --         "FluffyfootBunny",
    --         "FreddyFox",
    --         "FurbertSquirrel",
    --         "JacquesBeaver",
    --         "MoleyMole",
    --         "PancakeHedgehog",
    --         "Spiffo" }},
    --     {Name = "Maybe Helpful", Town = "FallusLake", Barricades = 90, Zombies = 30, Treasures = {"ElectronicsMag4"}}, -- GenMag
    -- }

require "ISBaseObject"
require "RicksMLC_TreasureHunt"

LuaEventManager.AddEvent("RicksMLC_TreasureHuntMgr_InitDone")
LuaEventManager.AddEvent("RicksMLC_TreasureHuntMgr_PreInit")

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

function RicksMLC_MapIDLookup:SetReadingMap(item) self.readingMapID = item end
function RicksMLC_MapIDLookup:GetReadingMap() return self.Lookup[self.readingMapID] end

-----------------------------------------
function RicksMLC_TreasureHuntMgr:GetMapPath()
    local mapLookup = RicksMLC_MapIDLookup.Instance():GetReadingMap()
    if not mapLookup then
        return RicksMLC_MapUtils.GetDefaultMapPath()
    end
    local mapPath = self.TreasureHunts[mapLookup.HuntId]:GetMapPath(mapLookup.MapNum)
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
    if not self.ModData then
        getGameTime():getModData()["RicksMLC_TreasureHuntMgr"] = {}
        self.ModData = {}
    end
end

function RicksMLC_TreasureHuntMgr:SaveModData()
    getGameTime():getModData()["RicksMLC_TreasureHuntMgr"] = self.ModData
end

function RicksMLC_TreasureHuntMgr:IsDuplicate(treasureHuntDefn, huntList)
    for i, defn in ipairs(huntList) do
        -- TODO: Make a name unique if required.  Just silently fail for now?
        if defn.Name == treasureHuntDefn.Name then return true end
    end
    return false
end

function RicksMLC_TreasureHuntMgr:UpdateTreasureHuntDefns(treasureHuntDefn)
    if self:IsDuplicate(treasureHuntDefn, self.ModData.TreasureHuntDefinitions) then return end

    self.ModData.TreasureHuntDefinitions[#self.ModData.TreasureHuntDefinitions+1] = treasureHuntDefn
    self:SaveModData()
end

-- Treasure Hunt Definitions: { Name = string, Barricades = {min, max} | n, Zombies = {min, max} | n, Treasures = {string, string...}, Town = nil | string) }
function RicksMLC_TreasureHuntMgr:AddTreasureHunt(treasureHuntDefn, isFromModData)
    if self:IsDuplicate(treasureHuntDefn, self.TreasureHunts) then return end

    self.TreasureHunts[#self.TreasureHunts+1] = RicksMLC_TreasureHunt:new(treasureHuntDefn, #self.TreasureHunts+1)
    self.TreasureHunts[#self.TreasureHunts]:InitTreasureHunt()
    local checkResult = self.TreasureHunts[#self.TreasureHunts]:CheckIfNewMapNeeded()
    if checkResult.NewMapNeeded then
        RicksMLC_TreasureHuntMgr.SetOnHitZombieForNewMap()
    end

    if isFromModData then return end -- Avoid infinite loop/leak by not adding to the ModData

    self:UpdateTreasureHuntDefns(treasureHuntDefn)
    return
end

function RicksMLC_TreasureHuntMgr:LoadTreasureHuntDefinitions(treasureHuntDefinitions, isFromModData)
    for i, treasureHuntDefn in ipairs(treasureHuntDefinitions) do
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr:LoadTreasureHuntDefinitions() '" .. treasureHuntDefn.Name .. "'")
        self:AddTreasureHunt(treasureHuntDefn, isFromModData)
    end
end

function RicksMLC_TreasureHuntMgr:InitTreasureHunts()
    triggerEvent("RicksMLC_TreasureHuntMgr_PreInit")
    self:LoadModData()
    if self.ModData.TreasureHuntDefinitions == nil then
        self.ModData.TreasureHuntDefinitions = {}
    else
        self:LoadTreasureHuntDefinitions(self.ModData.TreasureHuntDefinitions, true)
    end
end

-- This method provides compatibility with the vanilla StashDebug dialog
function RicksMLC_TreasureHuntMgr:GetMapFromTreasureHunt(name)
    for i, treasureHunt in ipairs(self.TreasureHunts) do
        if treasureHunt.Name == name then 
            return treasureHunt:GenerateNextTreasureMap()
        end
    end
    return nil
end

-- Special function for loading the sample treasure hunts once.
function RicksMLC_TreasureHuntMgr:LoadSampleTreasureHunts()
    if self.ModData.SamplesLoaded then return end

    RicksMLC_SampleTreasureHunts.LoadSampleTreasureHunts()

    self.ModData.SamplesLoaded = true
    self:SaveModData()
end

------------------------------------------------------------
-- Static methods

function RicksMLC_TreasureHuntMgr.OnHitZombie(zombie, character, bodyPartType, handWeapon)
    --DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr.OnHitZombie()")
    -- Make sure it's not just any character that hits the zombie

    if character == getPlayer() then
        for i, treasureHunt in ipairs(RicksMLC_TreasureHuntMgr.Instance().TreasureHunts) do
            treasureHunt:HandleOnHitZombie(zombie, character, bodyPartType, handWeapon)
        end
        Events.OnHitZombie.Remove(RicksMLC_TreasureHuntMgr.OnHitZombie)
    end
end

function RicksMLC_TreasureHuntMgr.HandleTransferItemPerform()
    -- Check if the inventory now contains a Treasure from one of the treasure hunts.
    local needNewMap = false
    local possibleItems = {}
    for _, treasureHunt in ipairs(RicksMLC_TreasureHuntMgr.Instance().TreasureHunts) do
        local checkResult = treasureHunt:CheckIfNewMapNeeded()
        needNewMap = checkResult.NewMapNeeded or needNewMap
        if #checkResult.UnassignedItems > 0 then
            for _, unassignedItem in ipairs(checkResult.UnassignedItems) do
                possibleItems[#possibleItems+1] = unassignedItem
            end
        end
    end
    for _, item in ipairs(possibleItems) do
        if item:getModData()["RicksMLC_Treasure"] == "Possible Treasure Item" then
            item:getModData()["RicksMLC_Treasure"] = "Not a treasure item"
        end
    end
    if needNewMap then 
        RicksMLC_TreasureHuntMgr.SetOnHitZombieForNewMap()
    end
end

function RicksMLC_TreasureHuntMgr:ResetLostMaps()
    for _, treasureHunt in ipairs(RicksMLC_TreasureHuntMgr.Instance().TreasureHunts) do
        treasureHunt:ResetLastSpawnedMapNum()
    end
    self:SetOnHitZombieForNewMap()
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
    RicksMLC_TreasureHuntMgr.Initialsed = true
    Events.EveryOneMinute.Remove(RicksMLC_TreasureHuntMgr.EveryOneMinuteAtStart)
    triggerEvent("RicksMLC_TreasureHuntMgr_InitDone") 
end

-- Use this for testing/prototyping only
function RicksMLC_TreasureHuntMgr.OnKeyPressed(key)
    if key == Keyboard.KEY_F10 then
    end
end

-- Commented out code - uncomment to make temp test
--Events.OnKeyPressed.Add(RicksMLC_TreasureHuntMgr.OnKeyPressed)
Events.OnGameStart.Add(RicksMLC_TreasureHuntMgr.OnGameStart)
