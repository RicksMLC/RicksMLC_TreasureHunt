-- RicksMLC_ISTreasureHuntsUI.lua
-- UI for development/inspection of the Treasure Hunts.
require "ISUI/ISCollapsableWindow"
require "RicksMLC_TreasureHuntMgr"

ISRicksMLC_TreasureHuntsUI = ISCollapsableWindow:derive("ISRicksMLC_TreasureHuntsUI");

ISRicksMLC_TreasureHuntsUI.instance = nil
ISRicksMLC_TreasureHuntsUI.defaultWindowWidth = 800
ISRicksMLC_TreasureHuntsUI.defaultWindowHeight = 500

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

local function isTable(o)
    return (type(o) == 'table')
end

------------------------------------------------------------------
-- TreasureHunt panel
-- Contains the details of a treasure hunt.
--      Treasure: item, location, zombies, barricades
--      Status: Defined | Generated | Activated (ie: map read) | Finished.
--      Owner: which player?
------------------------------------------------------------------

require "ISUI/ISPanel"
ISRicksMLC_TreasureHuntPanel = ISPanel:derive("ISTreasureHuntPanel")

function ISRicksMLC_TreasureHuntPanel:initialise()
    ISPanel.initialise(self)

end

function ISRicksMLC_TreasureHuntPanel:createChildren()
    ISPanel.createChildren(self)

end

function ISRicksMLC_TreasureHuntPanel:DrawArgList(name, arg, x, y, lineHeight)
    local txt = name .. ": "
    if RicksMLC_THSharedUtils.is_array(arg) then
        for i, v in ipairs(arg) do
            txt = txt .. ' [' .. i .. ']=' .. tostring(v) 
        end
    else
        if type(arg) == "table" then
            txt = txt .. "{"
            local comma = ""
            for k, v in pairs(arg) do
                txt = txt .. comma .. k .. "=" .. tostring(v)
                comma = ", "
            end
            txt = txt .. "}"
        else
            txt = txt .. tostring(arg)
        end
    end
    self:drawText(txt, x, y, 1, 1, 1, 1, UIFont.NewSmall)
    y = y + lineHeight
    return y
end

local function dispTextLen(text, font)
    return (text and getTextManager():MeasureStringX(font, text)) or 0
end

function ISRicksMLC_TreasureHuntPanel:DrawInvItemWithIcon(item, x, y, preLabel, postLabel)
    local tex = item:getTex()
    local iw = tex:getWidth() -- typically 32
    local ih = tex:getHeight() -- typically 29
    local preLabelLen = dispTextLen(preLabel, UIFontSmall)
    local postLabelLen = dispTextLen(postLabel, UIFontSmall)
    local dispNameLen = dispTextLen(item:getDisplayName(), UIFontSmall)
    local textY = y + ih - FONT_HGT_SMALL
    local texX = x + preLabelLen
    local dispNameX = texX + iw + 10
    local postX = dispNameX + dispNameLen
    local endX = postX + postLabelLen
    if x > self.xMargin + self.tab and endX > self:getWidth() - (self.xMargin + self.tab + self.xMargin) then
        -- Is not the first thing on the line (x > xMargin + self.tab) and runs over the right margin.
        y = y + ih + 2
        x = self.xMargin + self.tab
        textY = y + ih - FONT_HGT_SMALL
        texX = x + preLabelLen
        dispNameX = texX + iw + 10
        postX = dispNameX + dispNameLen
        endX = postX + postLabelLen
    end
    if preLabel then
        self:drawText(preLabel, x, textY, 1, 1, 1, 1, UIFont.NewSmall)
    end
    self:drawTexture(tex, texX , y, 1, 1, 1, 1) -- Tried ISUIElement:drawTextureScaled(texture, x, y, w, h, a, r, g, b) to enlarge, looks too chunky when scaled
    self:drawText(item:getDisplayName(), dispNameX, textY, 1, 1, 1, 1, UIFont.NewSmall)
    if postLabel then
        self:drawText(postLabel, postX, textY, 1, 1, 1, 1)
    end
    return endX, y, ih
end

function ISRicksMLC_TreasureHuntPanel:DrawItemsWithIcon(label, items, x, y)
    if not (isTable(items) and #items > 0) then return end

    local preLable = label
    local postLabel = nil
    local ih = nil
    local newX = nil
    for i, item in ipairs(items) do
        local invItem = InventoryItemFactory.CreateItem(item)
        if invItem then
            x, y, ih = self:DrawInvItemWithIcon(invItem, x, y, preLabel, postLabel)
        end
    end
    return y + ih + 2
end

function ISRicksMLC_TreasureHuntPanel:DrawTreasureItems(treasures, x, y)
    --TODO: Parse the various treasure defn formats for treasures
    -- v can be an item, a list with {Item = itemtype} or a list of {{Item=itemType}, item, {Item=itemType}}
    local itemList = {}
    for i, v in ipairs(treasures) do
        if isTable(v) then
            itemList[#itemList+1] = v.Item
        else
            itemList[#itemList+1] = v
        end
    end
    y = self:DrawItemsWithIcon("Treasures", itemList, x, y, true)
    return y
end

function ISRicksMLC_TreasureHuntPanel:DrawTreasureHuntDefn(treasureHuntDefn, x, y, lineHeight)
    -- Barricades
    -- Decorators
    -- Name
    -- Treasures | Treasure?
    -- Zombies
    -- Mode
    self:drawText("treasureHuntDefn:", x, y, 1, 1, 1, 1, UIFont.NewSmall)
    y = y + lineHeight
    x = self.xMargin + self.tab
    for k, v in pairs(treasureHuntDefn) do
        if k == "Treasures" then
            y = self:DrawTreasureItems(v, x, y)
            if y == nil then
                DebugLog.log(DebugType.Mod, "Treasures y is nil")
            end
        elseif k == "Name" then
            self:drawText(k .. ": " .. tostring(v), x, y, 1, 1, 1, 1, UIFont.NewSmall)
            y = y + lineHeight
        else
            y = self:DrawArgList(k, v, x, y, lineHeight)
        end
    end
    return y
end

function ISRicksMLC_TreasureHuntPanel:prerender()
    ISPanel.prerender(self)

    local yOffset = 0
    local x = self.xMargin
    -- ISPanel background will draw the border
    
    if self.treasureHuntInfo and self.treasureHuntInfo.error == nil then
        local lineHeight = FONT_HGT_SMALL + 2
        local y = yOffset
        -- self.treasureHuntInfo:
        -- {name = self.Name, huntId = self.HuntId, i = self.ModData.CurrentMapNum, finished = self.ModData.Finished,  tresureHuntDefn = self.TreasureHuntDefn, treasureModData = modData, modData = self.ModData}

        local thText = "Treasure Hunt " .. tostring(self.treasureHuntInfo.huntId) .. ": " .. self.treasureHuntInfo.Name .. (self.treasureHuntInfo.finished and "(finished)" or "(active)")

        self:drawText(thText, self.width/2 - (getTextManager():MeasureStringX(UIFont.NewSmall, thText) / 2), yOffset, 1, 1, 1, 1, UIFont.NewSmall)
        y = y + lineHeight

        --name = self.Name, huntId = self.HuntID, i = self.ModData.CurrentMapNum, finished = self.ModData.Finished,  treasureModData = modData}
        self:drawText("Treasure Hunt Item #: " .. tostring(self.treasureHuntInfo.i) .. " of " .. tostring(#self.treasureHuntInfo.treasureHuntDefn.Treasures), x, y, 1, 1, 1, 1, UIFont.NewSmall)
        -- treasureModData.Treasure is the internal name (type()) of the treasure item
        y = y + lineHeight
        if self.treasureHuntInfo.treasureHuntDefn then
            y = self:DrawTreasureHuntDefn(self.treasureHuntInfo.treasureHuntDefn, x, y, lineHeight)
        end

        self:drawText("Restrict to user: " .. (self.treasureHuntInfo.RestrictMapForUserName or "none"), x, y, 1, 1, 1, 1, UIFont.NewSmall)
        y = y + lineHeight

        if self.treasureHuntInfo.treasureModData then
            self:drawText("treasureModData:", x, y, 1, 1, 1, 1, UIFont.NewSmall)
            y = y + lineHeight
            x = self.xMargin + self.tab
            for k, v in pairs(self.treasureHuntInfo.treasureModData) do
                if k == "Treasure" then
                    local treaureItem = nil
                    if type(v) == "table" then
                        -- This is the "new" style of treasure definition, which is a list including the item.
                        -- Barricades n, Decorator "name", Item "name", ProceduralDefns {table of loot spawn}, Town {table}, Zombies n
                        treasureItem = InventoryItemFactory.CreateItem(v.Item)
                    else
                        treasureItem = InventoryItemFactory.CreateItem(self.treasureHuntInfo.treasureModData.Treasure)
                    end
                    if treasureItem then
                        _, y, ih = self:DrawInvItemWithIcon(treasureItem, x, y, k .. ": ", nil)
                        y = y + ih + 2
                    end        
                else
                    if type(v) == "table" then
                        local lvl2txt = k
                        for k2, v2 in pairs(v) do
                            lvl2txt = lvl2txt .. " : " .. k2 .. ": " .. tostring(v)
                        end
                        self:drawText(lvl2txt, x, y, 1, 1, 1, 1, UIFont.NewSmall)
                    else
                        self:drawText(k .. ": " .. tostring(v), x, y, 1, 1, 1, 1, UIFont.NewSmall)
                    end
                    y = y + lineHeight
                end
            end
            x = self.xMargin + self.tab
        else
            -- treasureModData does not exist yet, so the treasure map has not been generated yet.
            self:drawText("No treasureModData - map not generated yet?", x, y, 1, 1, 1, 1, UIFont.NewSmall)
        end
    end

    -- Show the window size at the bottom left. FIXME: Remove this when the layout is complete.
    z = self.height - (FONT_HGT_SMALL*2)
    local wSizeTxt = "panel size: " .. tostring(self.height) .. ", " .. tostring(self.width)
    self:drawText(wSizeTxt, x, z, 1, 1, 1, 1, UIFont.NewSmall)

end

function ISRicksMLC_TreasureHuntPanel:SetTreasureHunt(treasureHuntInfo)
    if not treasureHuntInfo then
        DebugLog.log(DebugType.Mod, "ISRicksMLC_TreasureHuntPanel:SetTreasureHunt() nil")
        return
    end
    self.treasureHuntInfo = treasureHuntInfo
end

function ISRicksMLC_TreasureHuntPanel:new(x, y, width, height, owner)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
    o.backgroundColor = {r=0, g=0, b=0, a=0.8};
    o.moveWithMouse = false
    o.background = true
    o.owner = owner
    o.treasureHuntNum = nil
    o.treasureHuntInfo = nil
    o.xMargin = 10
    o.tab = 6
    return o;  
end

------------------------------------------------------------------
-- TreasureHunts window (Treasure hunt mgr window)
------------------------------------------------------------------

function ISRicksMLC_TreasureHuntsUI:initialise()
    ISCollapsableWindow.initialise(self);
    self.title = getText("IGUI_RicksMLC_TreasureHuntDialogName")
    self.minimumWidth = 800
    self.minimumHeight = 650
end

function ISRicksMLC_TreasureHuntsUI:createChildren()
    ISCollapsableWindow.createChildren(self)

    local listX = 10
    local listWidth = 250
    local listY = 20 + FONT_HGT_MEDIUM + 20 -- to account for the header
    local listHeight = self.height - (listY + ((FONT_HGT_SMALL + 2) * 2)) -- allow for the footer display  -- was (FONT_HGT_SMALL + 2 * 2) * 8
    self.treasureHuntsListBox = ISScrollingListBox:new(listX, listY, listWidth, listHeight) -- self.width-20, fix to listWidth
    self.treasureHuntsListBox:initialise()
    self.treasureHuntsListBox:instantiate()
    self.treasureHuntsListBox.itemheight = FONT_HGT_SMALL + 2 * 2
    self.treasureHuntsListBox.selected = 0
    self.treasureHuntsListBox.joypadParent = self
    self.treasureHuntsListBox.font = UIFont.NewSmall
    self.treasureHuntsListBox.doDrawItem = self.drawTreasureHuntItem
    self.treasureHuntsListBox.drawBorder = true
    self.treasureHuntsListBox:setAnchorBottom(true) -- call the set() functions so the underlying javaObject is set.
    self:addChild(self.treasureHuntsListBox);

    local thPanelX = self.treasureHuntsListBox.width + 10
    local thPanelY = listY
    local thPanelWidth = self.width - (self.treasureHuntsListBox.width + listX + 10) -- 10 is the right margin to the window.
    local thPanelHeight = listHeight
    self.treasureHuntPanel = ISRicksMLC_TreasureHuntPanel:new(thPanelX, thPanelY, thPanelWidth, thPanelHeight, self)
    self.treasureHuntPanel:initialise()
    self.treasureHuntPanel:instantiate()
    self.treasureHuntPanel:setAnchorBottom(true)
    self.treasureHuntPanel:setAnchorRight(true)
    self:addChild(self.treasureHuntPanel)

    --SavedLayout.apply(self)
    ISRicksMLC_TreasureHuntsUI.OnTreasureHuntUpdate() -- Update the initial list of elements.
end

function ISRicksMLC_TreasureHuntsUI:populateList(treasureHuntList)
    self.treasureHuntsListBox:clear()

    -- for each treasure hunt in the treaureHuntMgr:
    treasureHuntList = treasureHuntList or RicksMLC_TreasureHuntMgr.Instance().TreasureHunts

    if not treasureHuntList then return end

    for i, treasureHunt in ipairs(treasureHuntList) do
        local displayName = treasureHunt.Name
        local treasureHuntInfo = {};
        treasureHuntInfo.name = treasureHunt.Name
        treasureHuntInfo.tooltip = "foo"
        treasureHuntInfo.treasureHuntNum = i
        local index = self.treasureHuntsListBox:addItem(displayName, treasureHuntInfo);
    end
end

function ISRicksMLC_TreasureHuntsUI:GetInfoFromMgr(treasureHuntNum)
    return RicksMLC_TreasureHuntMgr.Instance():GetCurrentTreasureHuntInfo(treasureHuntNum)
end

function ISRicksMLC_TreasureHuntsUI:drawTreasureHuntItem(y, item, alt)
    local a = 0.9;
    if self.selected == item.index then
        self:drawRectBorder(0, (y), self:getWidth(), self.itemheight - 1, a, self.borderColor.r, self.borderColor.g, self.borderColor.b);
        self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15); -- highlight the selected row with semi-transparent filled rect?

        -- Populate a panel with the treasure hunt details: Current stash, past stash, future items.
        -- "self" in this execution is the ISScrollingListBox instance, so the treasureHuntPanel is in the parent.
        local treasureHunt = self.parent.treasureHuntPanel.parent:GetInfoFromMgr(item.item.treasureHuntNum)
        self.parent.treasureHuntPanel:SetTreasureHunt(treasureHunt)
    end
    local itemPadY = self.itemPadY or (item.height - self.fontHgt) / 2
    self:drawText(item.item.name, 10, y + 1, 1, 1, 1, a, self.font) -- y + 2 made the text too low. y + 1 is centered.

    return y + self.itemheight;
end

function ISRicksMLC_TreasureHuntsUI:ShowSystemMsg()
    local z = self.height - (FONT_HGT_SMALL*2)
    self:drawText(self.systemMsg .. (self.systemErrMsg and ". " .. self.systemErrMsg or ""), 10, z, 1, 1, 1, 1, UIFont.NewSmall)
end

function ISRicksMLC_TreasureHuntsUI:GetWindowTitle()
    local windowTitle = getText("IGUI_RicksMLC_TreasureHuntDialogName") .. (isClient() and " - Client" or "")
    windowTitle = windowTitle .. " " .. RicksMLC_TreasureHuntMgr.Instance():GetMgrStatus() 
    return windowTitle
end

function ISRicksMLC_TreasureHuntsUI:prerender()
    local z = 20;
    local splitPoint = 100;
    local x = 10;

    self:SetSystemErrMsg("")
    
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b);
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b);
    local windowTitle = self:GetWindowTitle()
    self:drawText(windowTitle, self.width/2 - (getTextManager():MeasureStringX(UIFont.Medium, windowTitle) / 2), z, 1,1,1,1, UIFont.Medium);

    z = z + 30;

    -- Show the window size at the bottom left.
    self:SetSystemMsg("Window size: " .. tostring(self.height) .. ", " .. tostring(self.width))
    self:ShowSystemMsg()
end

function ISRicksMLC_TreasureHuntsUI:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    if y == 0 then
        o.y = o:getMouseY() - (height / 2)
        o:setY(o.y)
    end
    if x == 0 then
        o.x = o:getMouseX() - (width / 2)
        o:setX(o.x)
    end
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
    o.backgroundColor = {r=0, g=0, b=0, a=0.8};
    o.width = width
    o.height = height
    o.moveWithMouse = true
    o.systemMsg = ""
    o.systemErrMsg = ""
    return o;
end

function ISRicksMLC_TreasureHuntsUI:SetSystemMsg(msg)
    self.systemMsg = msg
end
function ISRicksMLC_TreasureHuntsUI:SetSystemErrMsg(msg)
    self.systemErrMsg = msg
end

function ISRicksMLC_TreasureHuntsUI:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    ISRicksMLC_TreasureHuntsUI.instance = nil
end

function ISRicksMLC_TreasureHuntsUI.openWindow()
    ISRicksMLC_TreasureHuntsUI.instance = ISRicksMLC_TreasureHuntsUI:new(
        getCore():getScreenWidth()/ 2 - 200,
        getCore():getScreenHeight() / 2 - 175,
        ISRicksMLC_TreasureHuntsUI.defaultWindowWidth, 
        ISRicksMLC_TreasureHuntsUI.defaultWindowHeight)
    ISRicksMLC_TreasureHuntsUI.instance:initialise()
    ISRicksMLC_TreasureHuntsUI.instance:addToUIManager()
    --FIXME: Remove ISLayoutManager.RegisterWindow('ISRicksMLC_TreasureHuntsUI', ISRicksMLC_TreasureHuntsUI, ISRicksMLC_TreasureHuntsUI.instance)
end

function ISRicksMLC_TreasureHuntsUI.HandleTreasureHuntUpdate()
    if ISRicksMLC_TreasureHuntsUI.instance then
        ISRicksMLC_TreasureHuntsUI.instance:populateList()
    end
end

----------------------------------------------------------
-- ISRicksMLC_TreasureHuntsServerUI - Subclass for showing the server data.
----------------------------------------------------------

ISRicksMLC_TreasureHuntsServerUI = ISRicksMLC_TreasureHuntsUI:derive("ISRicksMLC_TreasureHuntsServerUI")

ISRicksMLC_TreasureHuntsServerUI.serverInstance = nil
ISRicksMLC_TreasureHuntsServerUI.refreshTexture = getTexture("media/ui/refresh-yellow-transparent-32x32.png")


function ISRicksMLC_TreasureHuntsServerUI:GetWindowTitle()
    local windowTitle = getText("IGUI_RicksMLC_TreasureHuntDialogName") .. " - Server"
    local status = RicksMLC_TreasureHuntMgrClient.Instance():GetMgrStatusFromServer()
    if status.error then
        self:SetSystemErrMsg(status.error)
    else
        windowTitle = windowTitle .. " " .. status.text
    end
    return windowTitle
end

-- Override to get info from the chached server data
function ISRicksMLC_TreasureHuntsServerUI:GetInfoFromMgr(treasureHuntNum)
    local cachedData = RicksMLC_TreasureHuntMgrClient.Instance():GetCachedTreasureHuntInfo(treasureHuntNum)
    if not cachedData.data then
        self:SetSystemErrMsg(cachedData.error)
        return nil
    end
    return cachedData.data
end

function ISRicksMLC_TreasureHuntsServerUI:RequestUpdateFromServer()
    RicksMLC_TreasureHuntMgrClient.Instance():RefreshTreasureData()
    RicksMLC_TreasureHuntMgrClient.Instance():RefreshMgrServerStatus()
    self.refreshServerListButton:setEnable(false)
    self:populateList() -- clear the list
end

function ISRicksMLC_TreasureHuntsServerUI.CacheRefreshed(cmdModule, requestCmd, responseCmd)
    if not ISRicksMLC_TreasureHuntsServerUI.serverInstance then return end
    
    if responseCmd == "SentTreasureHuntList" then
        local cachedData = RicksMLC_TreasureHuntMgrClient.Instance():GetAllCachedTreasureHuntInfo()
        if not cachedData.data then
            ISRicksMLC_TreasureHuntsServerUI.serverInstance:SetSystemErrMsg(cachedData.error)
        end
        ISRicksMLC_TreasureHuntsServerUI.serverInstance:populateList(cachedData.data)
        ISRicksMLC_TreasureHuntsServerUI.serverInstance.waitingForServerList = false
        return
    end
    if responseCmd == "SentMgrServerStatus" then
        -- Nothing to be done?
    end
    ISRicksMLC_TreasureHuntsServerUI.serverInstance.refreshServerListButton:setEnable(true)
end

function ISRicksMLC_TreasureHuntsServerUI:ReceiveTreasureHuntInfoFromServer(args)
    if args.playerNum ~= getPlayer():getPlayerNum() then return end

    if self.treasureHuntPanel then
        self.treasureHuntPanel:SetTreasureHunt(args.treasureHuntInfo)
    end
end

function ISRicksMLC_TreasureHuntsServerUI:createChildren()
    ISRicksMLC_TreasureHuntsUI.createChildren(self)

    -- Add a refresh button.
    self.refreshServerListButton = ISButton:new(20, 20, 40, 40, "", self, ISRicksMLC_TreasureHuntsServerUI.onClick)
    self.refreshServerListButton:initialise()
    self.refreshServerListButton.internal = "REFRESH_LIST"
    self.refreshServerListButton.backgroundColor = {r=0, g=0, b=0, a=1.0}
    self.refreshServerListButton.backgroundColorMouseOver = {r=0.5, g=0.5, b=0.5, a=1}
    self.refreshServerListButton.borderColor = {r=1.0, g=1.0, b=1.0, a=0.3}
    self.refreshServerListButton.textureOverride = ISRicksMLC_TreasureHuntsServerUI.refreshTexture
    --button.customData = _data
    self:addChild(self.refreshServerListButton)
end

function ISRicksMLC_TreasureHuntsServerUI:populateList(treasureHuntList)
    if self.waitingForServerList then
        self.treasureHuntsListBox:clear()
        return
    end
    ISRicksMLC_TreasureHuntsUI.populateList(self, treasureHuntList)
end

function ISRicksMLC_TreasureHuntsServerUI:onClick(button)
    if button.internal == "REFRESH_LIST" then
        -- refresh from server
        self:RequestUpdateFromServer()
    end
end

function ISRicksMLC_TreasureHuntsServerUI:new(x, y, width, height)
    local o = ISRicksMLC_TreasureHuntsUI:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.refreshServerListButton = nil
    o.waitingForServerList = false

    return o
end

function ISRicksMLC_TreasureHuntsServerUI.openWindow()
    ISRicksMLC_TreasureHuntsServerUI.serverInstance = ISRicksMLC_TreasureHuntsServerUI:new(
        getCore():getScreenWidth() / 2 - 200,
        getCore():getScreenHeight() / 2 - 175, 
        ISRicksMLC_TreasureHuntsUI.defaultWindowWidth, 
        ISRicksMLC_TreasureHuntsUI.defaultWindowHeight)
    ISRicksMLC_TreasureHuntsServerUI.serverInstance:initialise()
    ISRicksMLC_TreasureHuntsServerUI.serverInstance:addToUIManager()
    --FIXME: Remove ISLayoutManager.RegisterWindow('ISRicksMLC_TreasureHuntsServerUI', ISRicksMLC_TreasureHuntsServerUI, ISRicksMLC_TreasureHuntsServerUI.serverInstance)
    Events.RicksMLC_CacheRefreshed.Remove(ISRicksMLC_TreasureHuntsServerUI.CacheRefreshed)
    Events.RicksMLC_CacheRefreshed.Add(ISRicksMLC_TreasureHuntsServerUI.CacheRefreshed)
end

function ISRicksMLC_TreasureHuntsServerUI:close()
    Events.RicksMLC_CacheRefreshed.Remove(ISRicksMLC_TreasureHuntsServerUI.CacheRefreshed)
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    ISRicksMLC_TreasureHuntsServerUI.serverInstance = nil
end

------------------------------------------------------------

Events.RicksMLC_TreasureHuntMgr_InitDone.Add(ISRicksMLC_TreasureHuntsUI.HandleTreasureHuntUpdate)
Events.RicksMLC_TreasureHuntMgr_AddTreasureHunt.Add(ISRicksMLC_TreasureHuntsUI.HandleTreasureHuntUpdate)

function ISRicksMLC_TreasureHuntsUI.DoContextMenu(player, context, worldobjects, test)
    -- Add the menu option to open the treasure hunts window.  Disable if the window already exists.
    local playerObj = getSpecificPlayer(player)

    local subMenu = context:getNew(context)
    local option = subMenu:addOption(getText("ContextMenu_RicksMLCShowTreasureHuntsWindow"), worldobjects, ISRicksMLC_TreasureHuntsUI.openWindow , player)
    local tooltip = ISWorldObjectContextMenu:addToolTip()
    tooltip.description = getText("ContextMenu_RicksMLCShowTreasureHuntsWindow_tooltip")
    option.toolTip = tooltip
    if ISRicksMLC_TreasureHuntsUI.instance then 
        option.notAvailable = true
    else
        option.notAvailable = false
    end

    if isClient() then
        local option = subMenu:addOption(getText("ContextMenu_RicksMLCShowServerTreasureHuntsWindow"), worldobjects, ISRicksMLC_TreasureHuntsServerUI.openWindow , player)
        local tooltip = ISWorldObjectContextMenu:addToolTip()
        tooltip.description = getText("ContextMenu_RicksMLCShowServerTreasureHuntsWindow_tooltip")
        option.toolTip = tooltip
        if ISRicksMLC_TreasureHuntsServerUI.serverInstance then 
            option.notAvailable = true
        else
            option.notAvailable = false
        end
    end

    local subMenuOption = context:addOption("Rick's MLC Treasure Hunt", nil, nil)
    context:addSubMenu(subMenuOption, subMenu)
end

function ISRicksMLC_TreasureHuntsUI.OnTreasureHuntUpdate()
    if ISRicksMLC_TreasureHuntsUI.instance then
        ISRicksMLC_TreasureHuntsUI.instance:populateList()
    end
end

Events.OnFillWorldObjectContextMenu.Add(ISRicksMLC_TreasureHuntsUI.DoContextMenu)
