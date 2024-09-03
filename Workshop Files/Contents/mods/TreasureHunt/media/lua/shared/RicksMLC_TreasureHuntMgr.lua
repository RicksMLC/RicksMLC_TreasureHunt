-- RicksMLC_TreasureHuntMgr.lua
-- Treasure Hunt Definitions: { Name = string, Barricades = {min, max} | n, Zombies = {min, max} | n, Treasures = {string, string...}, Town = nil | string) }
-- Example:
    -- o.TreasureHuntDefinitions = {
    --     {Name = "Spiffo And Friends", Town = nil, Barricades = {1, 100}, Zombies = {3, 15}, minTrapToSpawn = 1, Treasures = {
    --         "BorisBadger",
    --         "FluffyfootBunny",
    --         "FreddyFox",
    --         "FurbertSquirrel",
    --         "JacquesBeaver",
    --         "MoleyMole",
    --         "PancakeHedgehog",
    --         "Spiffo" },
    --      Decorators = {[2] = "FluffyFootDecorator"}
    --    },
    --    {Name = "Maybe Helpful", Town = "SampleEkronTown", Barricades = 90, Zombies = 30, Treasures = {"ElectronicsMag4"}, Decorators = {[1] = "SampleGenMagDecorator"}}, -- GenMag
    -- }

require "ISBaseObject"
require "RicksMLC_TreasureHunt"

LuaEventManager.AddEvent("RicksMLC_TreasureHuntMgr_InitDone")
LuaEventManager.AddEvent("RicksMLC_TreasureHuntMgr_PreInit")
LuaEventManager.AddEvent("RicksMLC_TreasureHuntMgr_AddTreasureHunt")

RicksMLC_TreasureHuntMgr = ISBaseObject:derive("RicksMLC_TreasureHuntMgr");

RicksMLC_TreasureHuntMgrInstance = RicksMLC_TreasureHuntMgrInstance or nil

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
    o.IsWaitingToHitZombie = false

    o.TreasureHunts = {}

    o.ModData = nil

    o.BulkLoading = false
    return o
end

-------------------------------------------
-- Map decorator function register.
-- Since the ModData cannot store function pointers the Decorators are registered with a name->fn lookup. 
-- The decorator in the TreasureHuntDefinition is the name of the decorator which is registered in the RicksMLC_MapDecorators.
RicksMLC_MapDecorators = ISBaseObject:derive("RicksMLC_MapDecorators")

RicksMLC_MapDecoratorsInstance = nil

function RicksMLC_MapDecorators.Instance()
    if not RicksMLC_MapDecoratorsInstance then
        RicksMLC_MapDecoratorsInstance = RicksMLC_MapDecorators:new()
    end
    return RicksMLC_MapDecoratorsInstance
end

function RicksMLC_MapDecorators:new()
	local o = {}
	setmetatable(o, self)
	self.__index = self

    o.decorators = {}

    return o
end

function RicksMLC_MapDecorators:Register(name, fn)
    self.decorators[name] = fn
end

function RicksMLC_MapDecorators:Get(name)
    return self.decorators[name]
end

-------------------------------------------
-- SetReadingMap is the external static function called by the override for the Read Map menu item.
RicksMLC_MapIDLookup = ISBaseObject:derive("RicksMLC_MapIDLookup")

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

function RicksMLC_MapIDLookup:GetMapLookup(mapId)
    return self.Lookup[mapId]
end

-----------------------------------------

function RicksMLC_TreasureHuntMgr:GetMgrStatus()
    if self.IsWaitingToHitZombie then
        return "Waiting to hit a zombie"
    end
    return ""
end

function RicksMLC_TreasureHuntMgr:GetMapPath()
    local mapLookup = RicksMLC_MapIDLookup.Instance():GetReadingMap()
    if not mapLookup then
        return RicksMLC_MapUtils.GetDefaultMapPath()
    end
    local mapPath = self.TreasureHunts[mapLookup.HuntId]:GetMapPath(mapLookup.MapNum)
    return mapPath or RicksMLC_MapUtils.GetDefaultMapPath()
end

function RicksMLC_TreasureHuntMgr:setBoundsInSquares(mapAPI)
    local currentMapInfo = self:FindCurrentlyReadTreasureHunt()
    if currentMapInfo then
        currentMapInfo.TreasureHunt:setBoundsInSquares(mapAPI, currentMapInfo.MapNum)
    end
end

function RicksMLC_TreasureHuntMgr:FindCurrentlyReadTreasureHunt()
    local mapLookup = RicksMLC_MapIDLookup.Instance():GetReadingMap()
    if mapLookup then
        return {TreasureHunt = self.TreasureHunts[mapLookup.HuntId], MapNum = mapLookup.MapNum}
    end
    return nil
end

function RicksMLC_TreasureHuntMgr:IsTreasureHuntNameUnique(name)
    for i, treasureHunt in ipairs(self.TreasureHunts) do
        if treasureHunt.Name == name then return false end
    end
    return true
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

function RicksMLC_TreasureHuntMgr:NewTreasureHunt(treasureHuntDefn, huntId)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr:NewTreasureHunt(): '" .. treasureHuntDefn.Name .. "'")
    return RicksMLC_TreasureHunt:new(treasureHuntDefn, huntId)
end

-- Treasure Hunt Definitions: { Name = string, Barricades = {min, max} | n, Zombies = {min, max} | n, Treasures = {string, string...}, Town = nil | string), Decorators = nil | {[n] = DecoratorName} }
-- Decorators: The DecoratorName is the name given to the registered decorator.  
--             The index to the decorator corresponds with the treasure item so a unique decorator can be assigned
--             to each treasure.
function RicksMLC_TreasureHuntMgr:AddTreasureHunt(treasureHuntDefn, isFromModData)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr:AddTreasureHunt() '" .. treasureHuntDefn.Name .. "'")
    if self:IsDuplicate(treasureHuntDefn, self.TreasureHunts) then return end

    self.TreasureHunts[#self.TreasureHunts+1] = self:NewTreasureHunt(treasureHuntDefn, #self.TreasureHunts+1)
    RicksMLC_THSharedUtils.DumpArgs(self.TreasureHunts[#self.TreasureHunts], 0, "RicksMLC_TreasureHuntMgr:AddTreasureHunt() before InitTreasureHunt()")
    self.TreasureHunts[#self.TreasureHunts]:InitTreasureHunt()

    if not isFromModData then 
        -- Avoid infinite loop/leak by not adding to the ModData
        self:UpdateTreasureHuntDefns(treasureHuntDefn)
    end
    RicksMLC_THSharedUtils.DumpArgs(self.TreasureHunts[#self.TreasureHunts], 0, "RicksMLC_TreasureHuntMgr:AddTreasureHunt() after InitTreasureHunt()")
    if not self.BulkLoading then
        -- This is a single treasure hunt, probably added from an external mod like ChatTreasure 
        self:HandleOnAddTreasureHunt(self.TreasureHunts[#self.TreasureHunts])
    end
    return self.TreasureHunts[#self.TreasureHunts] -- return the generated treasure hunt
end

function RicksMLC_TreasureHuntMgr:LoadTreasureHuntDefinitions(treasureHuntDefinitions, isFromModData)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr:LoadTreasureHuntDefinitions()")
    self.BulkLoading = true
    for i, treasureHuntDefn in ipairs(treasureHuntDefinitions) do
        DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr:LoadTreasureHuntDefinitions() '" .. treasureHuntDefn.Name .. "'")
        local treasureHunt = self:AddTreasureHunt(treasureHuntDefn, isFromModData)
        -- FIXME: Remove: triggerEvent("RicksMLC_TreasureHuntMgr_AddTreasureHunt", treasureHunt)
        -- replace with self:InitOnHitZombie() after the loop
    end
    self.BulkLoading = false
    self:InitOnHitZombie()
end

function RicksMLC_TreasureHuntMgr:InitOnHitZombie()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr:InitOnHitZombie()")
    for _, treasureHunt in ipairs(self.TreasureHunts) do
        if treasureHunt:IsNewMapNeeded() then
            DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr:InitOnHitZombie() call SetOnHitZombieForNewMap()")
            -- TODO: MP: Check this is the correct player
            self:SetOnHitZombieForNewMap(treasureHunt)
        end
    end
end

function RicksMLC_TreasureHuntMgr:InitTreasureHunts()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr:InitTreasureHunts()")
    triggerEvent("RicksMLC_TreasureHuntMgr_PreInit")
    self:LoadModData()
    if self.ModData.TreasureHuntDefinitions == nil then
        self.ModData.TreasureHuntDefinitions = {}
    else
        self:LoadTreasureHuntDefinitions(self.ModData.TreasureHuntDefinitions, true)
        self:InitOnHitZombie()
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

function RicksMLC_TreasureHuntMgr:HandleOnHitZombie(zombie, character, bodyPartType, handWeapon)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr.HandleOnHitZombie()")
    for i, treasureHunt in ipairs(self.TreasureHunts) do
        treasureHunt:HandleOnHitZombie(zombie, character, bodyPartType, handWeapon, true) -- doStash = true for non-client/server
    end
    RicksMLC_TreasureHuntMgr.Instance():SetWaitingToHitZombie(false)
    --end
end

function RicksMLC_TreasureHuntMgr:GetCurrentTreasureHuntInfo(treasureHuntNum)
    local retInfo = self.TreasureHunts[treasureHuntNum]:GetCurrentTreasureHuntInfo()
    return retInfo
end

------------------------------------------------------------
-- Static methods

function RicksMLC_TreasureHuntMgr.OnHitZombie(zombie, character, bodyPartType, handWeapon)
    --DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr.OnHitZombie()")
    -- Make sure it's not just any character that hits the zombie

    if character == getPlayer() then
        RicksMLC_TreasureHuntMgr.Instance():HandleOnHitZombie(zombie, character, bodyPartType, handWeapon)
        -- -- Note: OnHitZombie is a client-side event, so no need to check for not isServer()?
        -- FIXME: Remove
        -- if not isServer() and isClient() then
        --     -- Send the OnHitZombie message to the server
        --     local args = {zombie = zombie, character = character, bodyPartType = bodyPartType, handWeapon = handWeapon}
        --     sendClientCommand(getPlayer(), "RicksMLC_TreasureHuntMgr", "ClientOnHitZombie", args)
        -- else
        --     for i, treasureHunt in ipairs(RicksMLC_TreasureHuntMgr.Instance().TreasureHunts) do
        --         treasureHunt:HandleOnHitZombie(zombie, character, bodyPartType, handWeapon)
        --     end
        -- end
        Events.OnHitZombie.Remove(RicksMLC_TreasureHuntMgr.OnHitZombie)
    end
end

function RicksMLC_TreasureHuntMgr:RecordFoundTreasure(huntID, foundMapNum)
    -- Do nothing in the base class.
end

function RicksMLC_TreasureHuntMgr.HandleTransferItemPerform()
    -- Check if the inventory now contains a Treasure from one of the treasure hunts.
    local needNewMap = false
    local possibleItems = {}
    local neededNewMaps = {}
    for _, treasureHunt in ipairs(RicksMLC_TreasureHuntMgr.Instance().TreasureHunts) do
        local checkResult = treasureHunt:CheckIfNewMapNeeded(getPlayer())
        if checkResult.NewMapNeeded then
            neededNewMaps[#neededNewMaps+1] = treasureHunt
        end
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
        -- TODO: MP: Check this is the correct player: This is correct for SP and MP as it is checking the player inventory.
        for _, treasureHunt in ipairs(neededNewMaps) do
            RicksMLC_TreasureHuntMgr.Instance():SetOnHitZombieForNewMap(treasureHunt)
        end
    end
end

function RicksMLC_TreasureHuntMgr:SetWaitingToHitZombie(value, treasureHunt)
    self.IsWaitingToHitZombie = value
end

function RicksMLC_TreasureHuntMgr:ResetLostMaps()
    -- TODO: MP: Check this is the correct player
    for _, treasureHunt in ipairs(RicksMLC_TreasureHuntMgr.Instance().TreasureHunts) do
        treasureHunt:ResetLastSpawnedMapNum()
        self:SetOnHitZombieForNewMap(treasureHunt)
    end
end

function RicksMLC_TreasureHuntMgr:CheckIfNewMapNeeded()
    --FIXME: Muiltiplayer Code.  Needs implementing.  No effect in SP for now.
end

function RicksMLC_TreasureHuntMgr:SetOnHitZombieForNewMap(treasureMap)
    Events.OnHitZombie.Remove(RicksMLC_TreasureHuntMgr.OnHitZombie)
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr:SetOnHitZombieForNewMap() Waiting to hit a zombie")
    self:SetWaitingToHitZombie(true, treasureMap)
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
    if startCount < 5 then return end
    RicksMLC_TreasureHuntMgr.Instance():InitTreasureHunts()
    RicksMLC_TreasureHuntMgr.Initialsed = true
    Events.EveryOneMinute.Remove(RicksMLC_TreasureHuntMgr.EveryOneMinuteAtStart)
    triggerEvent("RicksMLC_TreasureHuntMgr_InitDone") 
end

function RicksMLC_TreasureHuntMgr:HandleOnAddTreasureHunt(newTreasureHunt)
    -- Override this on the server and client.
    local checkResult = newTreasureHunt:CheckIfNewMapNeeded(getPlayer()) -- Note: This is a client-only function
    if checkResult.NewMapNeeded then
        self:SetOnHitZombieForNewMap(newTreasureHunt)
    end
end

function RicksMLC_TreasureHuntMgr.OnAddTreasureHunt(newTreasureHunt)
    RicksMLC_TreasureHuntMgr.Instance():HandleOnAddTreasureHunt(newTreasureHunt)
end

-- Use this for testing/prototyping only
function RicksMLC_TreasureHuntMgr.OnKeyPressed(key)
    if key == Keyboard.KEY_F10 then
    end
end

-- Commented out code - uncomment to make temp test
--Events.OnKeyPressed.Add(RicksMLC_TreasureHuntMgr.OnKeyPressed)

if not isClient() and not isServer() then
    -- Ie: single player
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntMgr: stand alone. Add OnGameStart")
    Events.OnGameStart.Add(RicksMLC_TreasureHuntMgr.OnGameStart)
end
Events.RicksMLC_TreasureHuntMgr_AddTreasureHunt.Add(RicksMLC_TreasureHuntMgr.OnAddTreasureHunt)
Events.OnServerStarted.Add(RicksMLC_TreasureHuntMgr.OnServerStarted)
Events.OnClientCommand.Add(RicksMLC_TreasureHuntMgr.OnClientCommand)