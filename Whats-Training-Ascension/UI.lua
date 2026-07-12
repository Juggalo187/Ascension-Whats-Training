-- Spellbook skill line tab UI adapted for AscensionSpellbookFrame
local ADDON_NAME, wt = ...

local BOOKTYPE_SPELL = BOOKTYPE_SPELL
local MAX_ROWS = 22
local ROW_HEIGHT = 14

-- Use Ascension's spellbook frame
local SPELLBOOK = AscensionSpellbookFrame
if not SPELLBOOK then
    error("AscensionSpellbookFrame not found – this addon requires the Ascension client.")
end

-- Build texture paths dynamically from the actual addon folder name
local ADDON_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\"
local HIGHLIGHT_TEXTURE_PATH = ADDON_PATH .. "res\\highlight"
local LEFT_BG_TEXTURE_PATH   = ADDON_PATH .. "res\\left"
local RIGHT_BG_TEXTURE_PATH  = ADDON_PATH .. "res\\right"
local TAB_TEXTURE_PATH       = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Use the global GameTooltip for maximum compatibility
local tooltip = GameTooltip

-- ----------------------------------------------------------------------
-- Tooltip helpers (unchanged)
-- ----------------------------------------------------------------------
local function appendCostLine(spell)
    local cost = tonumber(spell and spell.cost or 0) or 0
    if cost > 0 then
        local coins = (spell and spell.formattedCost) or GetCoinTextureString(cost)
        if GetMoney and GetMoney() < cost then
            coins = RED_FONT_COLOR_CODE .. coins .. FONT_COLOR_CODE_CLOSE
        end
        tooltip:AddLine(" ")
        tooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE .. string.format(wt.L.COST_FORMAT, coins) .. FONT_COLOR_CODE_CLOSE)
    end
end

local function setTooltip(spell)
    tooltip:ClearLines()
    if not spell then
        tooltip:Show()
        return
    end

    local id = tonumber(spell.id or 0) or 0
    if id > 0 then
        local name = GetSpellInfo(id) or spell.name or "Unknown"
        local link = (GetSpellLink and GetSpellLink(id)) or nil
        if not link then
            link = string.format("|cff71d5ff|Hspell:%d|h[%s]|h|r", id, name)
        end
        if type(tooltip.SetHyperlink) == "function" then
            tooltip:SetHyperlink(link)
        elseif type(tooltip.SetSpellByID) == "function" then
            tooltip:SetSpellByID(id)
        else
            local title = name
            local sub = spell.formattedSubText or ""
            if sub ~= "" then title = title .. " " .. sub end
            tooltip:SetText(title, 1, 1, 1, 1, true)
        end
        appendCostLine(spell)
    else
        local title = (spell.name or "Unknown")
        local sub = spell.formattedSubText or ""
        if sub ~= "" then title = title .. " " .. sub end
        tooltip:SetText(title, 1, 1, 1, 1, true)
        appendCostLine(spell)
        if spell.tooltip and spell.tooltip ~= "" then
            tooltip:AddLine(" ")
            tooltip:AddLine(spell.tooltip, 0.9, 0.9, 0.9, true)
        end
    end
    tooltip:Show()
end

-- ----------------------------------------------------------------------
-- Row rendering (unchanged)
-- ----------------------------------------------------------------------
local function setRowSpell(row, spell)
    if not spell then
        row.currentSpell = nil
        row:Hide()
        return
    elseif spell.isHeader then
        row.spell:Hide()
        row.header:Show()
        row.header:SetText(spell.formattedName or "")
        row:SetID(0)
        row.highlight:SetTexture(nil)
    else
        row.header:Hide()
        row.isHeader = false
        row.highlight:SetTexture(HIGHLIGHT_TEXTURE_PATH)
        row.spell:Show()
        row.spell.label:SetText(spell.name or "")
        row.spell.subLabel:SetText(spell.formattedSubText or "")
        if not spell.hideLevel and (spell.formattedLevel and spell.formattedLevel ~= "") then
            row.spell.level:Show()
            row.spell.level:SetText(spell.formattedLevel)
            local c = spell.levelColor or { r = 1, g = 1, b = 1 }
            row.spell.level:SetTextColor(c.r, c.g, c.b)
        else
            row.spell.level:Hide()
        end
        row:SetID(spell.id or 0)
        row.spell.icon:SetTexture(spell.icon or TAB_TEXTURE_PATH)
    end

    row:SetScript("OnClick", nil)
    row.currentSpell = spell
    if tooltip:IsOwned(row) then setTooltip(spell) end
    row:Show()
end

local lastOffset = -1
function wt.Update(frame, forceUpdate)
    local scrollBar = frame.scrollBar
    local offset = FauxScrollFrame_GetOffset(scrollBar)
    if (offset == lastOffset and not forceUpdate) then
        if wt.UpdateTotals then wt.UpdateTotals() end
        return
    end

    for i, row in ipairs(frame.rows) do
        local idx = i + offset
        local spell = wt.data[idx]
        setRowSpell(row, spell)
    end

    FauxScrollFrame_Update(frame.scrollBar, #wt.data, MAX_ROWS, ROW_HEIGHT, nil, nil, nil, nil, nil, nil, true)
    lastOffset = offset
    if wt.UpdateTotals then wt.UpdateTotals() end
end

-- ----------------------------------------------------------------------
-- Custom side tab management for Ascension
-- ----------------------------------------------------------------------
local customTab = nil
local customTabIndex = nil

-- Find the LAST unused side tab (highest index) to avoid breaking the chain
local function FindLastUnusedSideTab()
    for i = 19, 1, -1 do
        local tab = SPELLBOOK.SideBar["Tab"..i]
        if tab and not tab.HasInfo then
            return tab, i
        end
    end
    return nil, nil
end

-- Set up our custom tab
local function SetupCustomTab()
    if customTab then return end

    local tab, idx = FindLastUnusedSideTab()
    if not tab then
        print("|cff66ccff[WT:Ascension]|r Warning: No free side tab found. Custom tab will not appear.")
        return
    end

    customTab = tab
    customTabIndex = idx

    tab.HasInfo = true
    tab:Show()
    tab:SetID(999)
    tab.offset = 0
    tab.numSpells = 0

    -- Reposition to the bottom
    tab:ClearAllPoints()
    tab:SetPoint("BOTTOMLEFT", SPELLBOOK.SideBar, "BOTTOMLEFT", 0, 5)

    -- Set texture
    local useClass = WT_AscensionAccountDB and WT_AscensionAccountDB.useClassTabIcon
    if useClass then
        local classToken = select(2, UnitClass("player"))
        if CLASS_ICON_TCOORDS and classToken and CLASS_ICON_TCOORDS[classToken] then
            local c = CLASS_ICON_TCOORDS[classToken]
            tab.NormalTexture:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
            tab.NormalTexture:SetTexCoord(c[1], c[2], c[3], c[4])
        else
            tab.NormalTexture:SetTexture(TAB_TEXTURE_PATH)
            tab.NormalTexture:SetTexCoord(0,1,0,1)
        end
    else
        tab.NormalTexture:SetTexture(TAB_TEXTURE_PATH)
        tab.NormalTexture:SetTexCoord(0,1,0,1)
    end
    tab.tooltip = wt.L.TAB_TEXT

    -- Hook SelectSideTab
    if not wt._sideTabHooked then
        hooksecurefunc(SPELLBOOK, "SelectSideTab", function(self, tab)
            if tab == customTab then
                if wt.MainFrame then wt.MainFrame:Show() end
                if type(wt.RebuildData) == "function" then wt.RebuildData() end
                if wt.MainFrame and type(wt.Update) == "function" then
                    wt.Update(wt.MainFrame, true)
                end
            else
                if wt.MainFrame then wt.MainFrame:Hide() end
            end
        end)
        wt._sideTabHooked = true
    end

    -- Hook UpdateSideTabs
    if not wt._updateSideTabsHooked then
        hooksecurefunc(SPELLBOOK, "UpdateSideTabs", function(self)
            if customTab then
                if customTab:GetID() ~= 999 then
                    customTab = nil
                    customTabIndex = nil
                    SetupCustomTab()
                else
                    customTab:Show()
                    customTab.HasInfo = true
                    customTab.offset = 0
                    customTab.numSpells = 0
                    customTab:ClearAllPoints()
                    customTab:SetPoint("BOTTOMLEFT", SPELLBOOK.SideBar, "BOTTOMLEFT", 0, 5)
                    -- Update icon
                    local useClass = WT_AscensionAccountDB and WT_AscensionAccountDB.useClassTabIcon
                    if useClass then
                        local classToken = select(2, UnitClass("player"))
                        if CLASS_ICON_TCOORDS and classToken and CLASS_ICON_TCOORDS[classToken] then
                            local c = CLASS_ICON_TCOORDS[classToken]
                            customTab.NormalTexture:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
                            customTab.NormalTexture:SetTexCoord(c[1], c[2], c[3], c[4])
                        else
                            customTab.NormalTexture:SetTexture(TAB_TEXTURE_PATH)
                            customTab.NormalTexture:SetTexCoord(0,1,0,1)
                        end
                    else
                        customTab.NormalTexture:SetTexture(TAB_TEXTURE_PATH)
                        customTab.NormalTexture:SetTexCoord(0,1,0,1)
                    end
                end
            end
        end)
        wt._updateSideTabsHooked = true
    end
end

-- ----------------------------------------------------------------------
-- Main frame creation (adapted to Ascension)
-- ----------------------------------------------------------------------
local hasFrameShown = false
function wt.CreateFrame()
    if wt.MainFrame and wt.MainFrame._initialized then return end

    SetupCustomTab()

    local mainFrame = wt.MainFrame
    if not mainFrame then
        mainFrame = CreateFrame("Frame", "WhatsTrainingFrame", SPELLBOOK.Content)
        wt.MainFrame = mainFrame
    end
    mainFrame._initialized = true
    mainFrame:SetPoint("TOPLEFT", SPELLBOOK.Content, "TOPLEFT", 0, 0)
    mainFrame:SetPoint("BOTTOMRIGHT", SPELLBOOK.Content, "BOTTOMRIGHT", 0, 0)
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:Hide()

    -- ----------------------------------------------------------
    -- Background: left fixed width, right stretches to fill gap
    -- ----------------------------------------------------------
    local left = mainFrame:CreateTexture(nil, "ARTWORK")
    left:SetTexture(LEFT_BG_TEXTURE_PATH)
    left:SetWidth(256)
    left:SetPoint("TOPLEFT", mainFrame)
    left:SetPoint("BOTTOMLEFT", mainFrame)

    local right = mainFrame:CreateTexture(nil, "ARTWORK")
    right:SetTexture(RIGHT_BG_TEXTURE_PATH)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT")
    right:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT")
    right:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT")
    -- No width set – it will stretch horizontally

    -- Scrollable content container
    local content = CreateFrame("Frame", "$parentContent", mainFrame)
    mainFrame.content = content
    content:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 26, -78)
    content:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -65, 81)

    -- Total cost label
    local totalText = mainFrame:CreateFontString("$parentTotalCost", "OVERLAY", "GameFontNormal")
    totalText:SetJustifyH("RIGHT")
    totalText:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -72, -62)
    totalText:Hide()
    mainFrame.totalCostText = totalText

    function wt.UpdateTotals()
        if not wt.MainFrame or not wt.MainFrame.totalCostText then return end
        local t = wt.totals or {}
        if t.hasData and (t.availableCost or 0) >= 0 then
            local txt = string.format(wt.L.TOTALCOST_FORMAT, GetCoinTextureString(t.availableCost or 0))
            wt.MainFrame.totalCostText:SetText(txt)
            wt.MainFrame.totalCostText:Show()
        else
            wt.MainFrame.totalCostText:SetText("")
            wt.MainFrame.totalCostText:Hide()
        end
    end

    -- FauxScrollFrame
    local scrollBar = CreateFrame("ScrollFrame", "$parentScrollBar", mainFrame, "FauxScrollFrameTemplate")
    mainFrame.scrollBar = scrollBar
    scrollBar:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    scrollBar:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    scrollBar:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function() wt.Update(mainFrame) end)
    end)
    scrollBar:SetScript("OnShow", function()
        if not hasFrameShown then
            wt.RebuildData()
            hasFrameShown = true
        end
        wt.Update(mainFrame, true)
    end)

    -- Build rows
    local rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", "$parentRow" .. i, content)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("LEFT", content, "LEFT", 0, 0)
        row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        row:EnableMouse(true)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnEnter", function(self)
            tooltip:SetOwner(self, "ANCHOR_RIGHT")
            setTooltip(self.currentSpell)
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local highlight = row:CreateTexture("$parentHighlight", "HIGHLIGHT")
        highlight:SetAllPoints()

        local spell = CreateFrame("Frame", "$parentSpell", row)
        spell:SetPoint("LEFT", row, "LEFT")
        spell:SetPoint("TOP", row, "TOP")
        spell:SetPoint("BOTTOM", row, "BOTTOM")
        spell:SetPoint("RIGHT", row, "RIGHT")

        local spellIcon = spell:CreateTexture(nil, "ARTWORK")
        spellIcon:SetPoint("TOPLEFT", spell)
        spellIcon:SetPoint("BOTTOMLEFT", spell)
        spellIcon:SetWidth(ROW_HEIGHT)

        local spellLabel = spell:CreateFontString("$parentLabel", "OVERLAY", "GameFontNormal")
        spellLabel:SetPoint("LEFT", spell, "LEFT", ROW_HEIGHT + 4, 0)
        spellLabel:SetPoint("TOP", row, "TOP", 0, 0)
        spellLabel:SetPoint("BOTTOM", row, "BOTTOM", 0, 0)
        spellLabel:SetJustifyV("MIDDLE")
        spellLabel:SetJustifyH("LEFT")

        local spellLevelLabel = spell:CreateFontString("$parentLevelLabel", "OVERLAY", "GameFontWhite")
        spellLevelLabel:SetPoint("RIGHT", content, "RIGHT", -20, 0)
        spellLevelLabel:SetPoint("TOP", row, "TOP", 0, 0)
        spellLevelLabel:SetPoint("BOTTOM", row, "BOTTOM", 0, 0)
        spellLevelLabel:SetJustifyH("RIGHT")
        spellLevelLabel:SetJustifyV("MIDDLE")

        local spellSublabel = spell:CreateFontString("$parentSubLabel", "OVERLAY", "SpellFont_Small")
        spellSublabel:SetTextColor(255/255, 255/255, 153/255)
        spellSublabel:SetJustifyH("LEFT")
        spellSublabel:SetJustifyV("MIDDLE")
        spellSublabel:SetPoint("LEFT", spellLabel, "RIGHT", 2, 0)
        spellSublabel:SetPoint("RIGHT", spellLevelLabel, "LEFT", -4, 0)
        spellSublabel:SetPoint("TOP", row, "TOP", 0, 0)
        spellSublabel:SetPoint("BOTTOM", row, "BOTTOM", 0, 0)

        local headerLabel = row:CreateFontString("$parentHeaderLabel", "OVERLAY", "GameFontWhite")
        headerLabel:SetAllPoints()
        headerLabel:SetJustifyV("MIDDLE")
        headerLabel:SetJustifyH("CENTER")

        spell.label = spellLabel
        spell.subLabel = spellSublabel
        spell.icon = spellIcon
        spell.level = spellLevelLabel
        row.highlight = highlight
        row.header = headerLabel
        row.spell = spell

        if rows[i - 1] == nil then
            row:SetPoint("TOPLEFT", content, 0, 0)
        else
            row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -2)
        end

        rows[i] = row
    end
    mainFrame.rows = rows

    -- Hook OnShow
    if not wt._spellbookShowHooked then
        hooksecurefunc(SPELLBOOK, "OnShow", function(self)
            if customTab and self.selectedSideTab == customTab then
                if wt.MainFrame then
                    wt.MainFrame:Show()
                    if type(wt.RebuildData) == "function" then wt.RebuildData() end
                    if type(wt.Update) == "function" then wt.Update(wt.MainFrame, true) end
                end
            else
                if wt.MainFrame then wt.MainFrame:Hide() end
            end
        end)
        wt._spellbookShowHooked = true
    end

    if SPELLBOOK:IsShown() then
        if customTab and SPELLBOOK.selectedSideTab == customTab then
            wt.MainFrame:Show()
            wt.RebuildData()
            wt.Update(wt.MainFrame, true)
        else
            wt.MainFrame:Hide()
        end
    end
end

-- Icon toggle integration
local origApplyIcon = ApplyWTTabIcon
if origApplyIcon then
    local function ApplyWTTabIconWithCustom()
        if origApplyIcon then origApplyIcon() end
        if customTab then
            local useClass = WT_AscensionAccountDB and WT_AscensionAccountDB.useClassTabIcon
            if useClass then
                local classToken = select(2, UnitClass("player"))
                if CLASS_ICON_TCOORDS and classToken and CLASS_ICON_TCOORDS[classToken] then
                    local c = CLASS_ICON_TCOORDS[classToken]
                    customTab.NormalTexture:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
                    customTab.NormalTexture:SetTexCoord(c[1], c[2], c[3], c[4])
                else
                    customTab.NormalTexture:SetTexture(TAB_TEXTURE_PATH)
                    customTab.NormalTexture:SetTexCoord(0,1,0,1)
                end
            else
                customTab.NormalTexture:SetTexture(TAB_TEXTURE_PATH)
                customTab.NormalTexture:SetTexCoord(0,1,0,1)
            end
        end
    end
    _G.ApplyWTTabIcon = ApplyWTTabIconWithCustom
end