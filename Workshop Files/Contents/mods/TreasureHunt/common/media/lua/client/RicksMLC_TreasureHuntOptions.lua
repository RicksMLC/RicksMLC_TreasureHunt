-- RicksMLC_TreasureHuntOptions.lua
-- Mod options for the Treasure Hunt mod:
--  [+] Enable/Disable Treasure Hunt Mgr menu - turn off to avoid spoiles.
--  [+] Map size - Small, Medium, Large

RicksMLC_TreasureHuntOptions = {
    options = nil,
    mgrMenuOption = nil,
    mapSizeOption = nil
}

function RicksMLC_TreasureHuntOptions:init()
    DebugLog.log(DebugType.Mod, "RicksMLC_TreasureHuntOptions.init()")
    self.options = PZAPI.ModOptions:create("RicksMLC_TreasureHuntOptions", "Rick's MLC Treasure Hunt")
    self.mgrMenuOption = self.options:addTickBox("0", getText("UI_RicksMLC_TreasureHuntOptions_EnableMgrMenuOption"), true, getText("UI_RicksMLC_TreasureHuntOptions_EnableMgrMenuOption_Tooltip"))
    self.mapSizeOption = self.options:addComboBox("1", getText("UI_RicksMLC_TreasureHuntOptions_MapSizeOption"), getText("UI_RicksMLC_TreasureHuntOptions_MapSizeOption_Tooltip"))
    self.mapSizeOption:addItem(getText("UI_optionscreen_Small", true))
    self.mapSizeOption:addItem(getText("UI_optionscreen_Medium"))
    self.mapSizeOption:addItem(getText("UI_optionscreen_Large"))

end

function RicksMLC_TreasureHuntOptions:IsMgrMenuOn()
    return self.mgrMenuOption:getValue()
end

function RicksMLC_TreasureHuntOptions:GetMapDxDy()
    local size = self.mapSizeOption:getValue()
    if size == 1 then
        return 150, 100
    elseif size == 2 then
        return 300, 200
    elseif size == 3 then
        return 600, 400
    end
    return 300, 200
end

RicksMLC_TreasureHuntOptions:init()
