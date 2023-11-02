-- Test Concussion.lua
-- Rick's MLC Concussion

-- [ ] Test the RemoveGrassWithTool mod 
--

require "ISBaseObject"

require "RicksMLC_TreasureHuntMgr"

local MockPlayer = ISBaseObject:derive("MockPlayer");
function MockPlayer:new(player)
    local o = {} 
    setmetatable(o, self)
    self.__index = self

    o.realPlayer = player
    o.lastThought = nil

    return o
end

function MockPlayer:Move(direction) self.realPlayer:Move(direction) end

function MockPlayer:getForwardDirection() return self.realPlayer:getForwardDirection() end

function MockPlayer:setForwardDirection(fwdDirVec) self.realPlayer:setForwardDirection(fwdDirVec) end

function MockPlayer:setForceSprint(value) self.realPlayer:setForceSprint(value) end

function MockPlayer:setSprinting(value) self.realPlayer:setSprinting(value) end

function MockPlayer:getPlayerNum() return self.realPlayer:getPlayerNum() end

function MockPlayer:getPerkLevel(perkType) return self.realPlayer:getPerkLevel(perkLevel) end

function MockPlayer:getXp() return self.realPlayer:getXp() end

function MockPlayer:getPrimaryHandItem() return self.realPlayer:getPrimaryHandItem() end

function MockPlayer:setPrimaryHandItem(item) self.realPlayer:setPrimaryHandItem(item) end

function MockPlayer:getSecondaryHandItem() return self.realPlayer:getSecondaryHandItem() end

function MockPlayer:setSecondaryHandItem(item) self.realPlayer:setSecondaryHandItem(item) end

function MockPlayer:isTimedActionInstant() return false end

function MockPlayer:getTimedActionTimeModifier() return self.realPlayer:getTimedActionTimeModifier() end

function MockPlayer:Say(text, r, g, b, font, n, preset)
    self.realPlayer:Say(text, r, g, b, font, n, preset)
    self.lastThought = text
    DebugLog.log(DebugType.Mod, "MockPlayer:Say() end: " .. text)
end

function MockPlayer:getMoodles() return self.realPlayer:getMoodles() end

function MockPlayer:getBodyDamage() return self.realPlayer:getBodyDamage() end

----------------------------------------------------------------------

local TreasureHunt_Test = ISBaseObject:derive("TreasureHunt_Test")
local iTest = nil

function TreasureHunt_Test:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.player = nil

    o.riverSideSchoolTestDefn = {Name = "Test: Riverside School", Town = "SpecialCase", Barricades = {80, 100}, Zombies = {1, 5}, Treasures = {"SpiffoBig"}}
    o.powerBoxTestDefn = {Name = "Test: Local Power Box", Town = "PowerBox", Barricades = 0, Zombies = 0, Treasures = {"SpiffoBig"}}

    o.isReady = false
    o.resultsWindow = nil
    o.testResults = {}
    return o
end

function TreasureHunt_Test:newInventoryItem(type)
	local item = nil
    if type ~= nil then 
        item = InventoryItemFactory.CreateItem(type)
    end
	return item
end

function TreasureHunt_Test:Run()
    DebugLog.log(DebugType.Mod, "TreasureHunt_Test:Run()")
    if not self.isReady then
        DebugLog.log(DebugType.Mod, "TreasureHunt_Test:Run() not ready")
        return
    end
    DebugLog.log(DebugType.Mod, "TreasureHunt_Test:Run() begin")

    -- local bounds = {8100, 7310, 8699, 7799, 'media/maps/Greenport'} -- Town bounds and map name
    -- RicksMLC_MapUtils.AddTown("Greenport", bounds)
    RicksMLC_MapUtils.AddTown("SpecialCase", {6416, 5420, 6467, 5476, defaultMap}) -- Riverside school
    RicksMLC_MapUtils.AddTown("PowerBox", {8173, 11213, 8178, 11218, defaultMap}) -- Power box Rosewood

    RicksMLC_TreasureHuntMgr.Instance():AddTreasureHunt(self.riverSideSchoolTestDefn, true) -- Force map onto first zombie
    RicksMLC_TreasureHuntMgr.Instance():AddTreasureHunt(self.powerBoxTestDefn, true) -- Force map onto first zombie

    self.resultsWindow:createChildren()

    DebugLog.log(DebugType.Mod, "TreasureHunt_Test:Run() end")
end

function TreasureHunt_Test:Init()
    DebugLog.log(DebugType.Mod, "TreasureHunt_Test:Init()")
    -- Create the test instance of the ISRemoveGrass

    self.player = MockPlayer:new(getPlayer())

    self:CreateWindow()

    -- Create the object instances to test, if any
    
    self.isReady = true
end

function TreasureHunt_Test:CreateWindow()
    if self.resultsWindow then
        self.resultsWindow:setObject(self.testResults)
    else
        DebugLog.log(DebugType.Mod, "TreasureHunt_Test:CreateWindow()")
        local x = getPlayerScreenLeft(self.player:getPlayerNum())
        local y = getPlayerScreenTop(self.player:getPlayerNum())
        local w = getPlayerScreenWidth(self.player:getPlayerNum())
        local h = getPlayerScreenHeight(self.player:getPlayerNum())
        self.resultsWindow = _Test_RicksMLC_UI_Window:new(x + 70, y + 50, self.player, self.testResults)
        self.resultsWindow:initialise()
        self.resultsWindow:addToUIManager()
        _Test_RicksMLC_UI_Window.windows[self.player] = window
        if self.player:getPlayerNum() == 0 then
            ISLayoutManager.RegisterWindow('TreasureHunt_Test', ISCollapsableWindow, self.resultsWindow)
        end
    end

    self.resultsWindow:setVisible(true)
    self.resultsWindow:addToUIManager()
    local joypadData = JoypadState.players[self.player:getPlayerNum()+1]
    if joypadData then
        joypadData.focus = window
    end
end

function TreasureHunt_Test:Teardown()
    DebugLog.log(DebugType.Mod, "TreasureHunt_Test:Teardown()")
    self.isReady = false
end

-- Static --

function TreasureHunt_Test.IsTestSave()
    local saveInfo = getSaveInfo(getWorld():getWorld())
    DebugLog.log(DebugType.Mod, "TreasureHunt_Test.OnLoad() '" .. saveInfo.saveName .. "'")
	return saveInfo.saveName and saveInfo.saveName == "RicksMLC_TreasureHunt_Test"
end

function TreasureHunt_Test.Execute()
    iTest = TreasureHunt_Test:new()
    iTest:Init()
    if iTest.isReady then 
        DebugLog.log(DebugType.Mod, "TreasureHunt_Test.Execute() isReady")
        iTest:Run()
        DebugLog.log(DebugType.Mod, "TreasureHunt_Test.Execute() Run complete.")
    end
    iTest:Teardown()
    iTest = nil
end

function TreasureHunt_Test.OnLoad()
    -- Check the loaded save is a test save?
    DebugLog.log(DebugType.Mod, "TreasureHunt_Test.OnLoad()")
	if TreasureHunt_Test.IsTestSave() then
        DebugLog.log(DebugType.Mod, "  - Test File Loaded")
        --FIXME: This is auto run: TreasureHunt_Test.Execute()
    end
end

function TreasureHunt_Test.OnGameStart()
    DebugLog.log(DebugType.Mod, "TreasureHunt_Test.OnGameStart()")
end

function TreasureHunt_Test.HandleOnKeyPressed(key)
	-- Hard coded to F10 for now
	if key == nil then return end

	if key == Keyboard.KEY_F10 and TreasureHunt_Test.IsTestSave() then
        DebugLog.log(DebugLog.Mod, "TreasureHunt_Test.HandleOnKeyPressed() Execute test")
        TreasureHunt_Test.Execute()
    end
end

Events.OnKeyPressed.Add(TreasureHunt_Test.HandleOnKeyPressed)

Events.OnGameStart.Add(TreasureHunt_Test.OnGameStart)
Events.OnLoad.Add(TreasureHunt_Test.OnLoad)
