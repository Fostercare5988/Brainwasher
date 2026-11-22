-- Brainwasher: the rows that stand in the gossip window while the Goblin Brainwashing Device
-- talks, the Edit menu and the icon picker. Device.lua does the work.
local _, ns = ...

local ICONS = "Interface\\Icons\\"
local QUESTION = ICONS .. "INV_Misc_QuestionMark"
local GRID, CELL = 6, 46 -- the picker shows 6 x 6 icons
local panel, picker, provider
local rows = {}

local function Button(parent, text, width, click)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 20)
    button:SetText(text)
    button:SetScript("OnClick", click)
    return button
end

local function Text(parent, font, width)
    local text = parent:CreateFontString(nil, "OVERLAY", font)
    text:SetWidth(width)
    text:SetMaxLines(1) -- ends in "..." when too wide (API.md, fontstring:SetMaxLines)
    text:SetJustifyH("LEFT")
    return text
end

-- The slot's ActionBars profile, and whether ActionBars has lost it.
local function Bars(slot)
    local name = ns.Names() and BrainwasherDB[slot] and BrainwasherDB[slot].bars
    return name, name and not ns.HasProfile(name)
end

local function Colored(split)
    local hi, lo, out = math.max(split[1], split[2], split[3]), math.min(split[1], split[2], split[3]), {}
    for i = 1, 3 do
        out[i] = (split[i] == hi and "|cff00ff00" or split[i] == lo and "|cff0077ff" or "|cffffff00") .. split[i] .. "|r"
    end
    return table.concat(out, "/")
end

-- A slot nobody has set up shows the icon of its main tree.
local function Icon(slot)
    local split = ns.menu.split[slot]
    if BrainwasherDB[slot] and BrainwasherDB[slot].icon then return BrainwasherDB[slot].icon end
    if not split then return QUESTION end
    local _, icon = GetTalentTabInfo(split[1] >= split[2] and split[1] >= split[3] and 1 or split[2] >= split[3] and 2 or 3)
    return icon or QUESTION
end

local function Tip(row)
    local slot, split = row.slot, ns.menu.split[row.slot]
    local bars, missing = Bars(slot)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(ns.Name(slot), 1, 1, 1)
    if row.active:IsShown() then GameTooltip:AddLine("Active now", 0.3, 1, 0.3) end
    if split then GameTooltip:AddLine("Talents: " .. split[1] .. "/" .. split[2] .. "/" .. split[3], 1, 1, 1) end
    if bars then GameTooltip:AddLine("Action bars: " .. bars .. (missing and " (no longer in ActionBars)" or ""), 0.8, 0.8, 0.8) end
    GameTooltip:Show()
end

-- The icon picker: ClassicAPI's IconDataProviderMixin (embedded Lua, Util/IconDataProvider.lua)
-- lists the spellbook's and talents' icons first, then every spell and item icon.
local function Fill()
    for i, button in ipairs(picker.buttons) do
        button.path = provider:GetIconByIndex(picker.first + i - 1)
        button.texture:SetTexture(button.path)
        button:SetShown(button.path)
    end
end

local function Pick(slot)
    if not picker then
        picker = CreateFrame("Frame", "BrainwasherPicker", panel)
        picker:SetAllPoints(panel)
        picker:SetFrameLevel(panel:GetFrameLevel() + 10)
        picker:EnableMouse(true)
        picker:EnableMouseWheel(true)
        picker:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        picker:SetBackdropColor(0, 0, 0, 1)
        picker:SetScript("OnMouseWheel", function()
            picker.first = math.max(1, math.min(provider:GetNumIcons() - GRID * GRID + 1, picker.first - arg1 * GRID))
            Fill()
        end)
        picker:SetScript("OnHide", function() provider:Release(); provider = nil end)
        Button(picker, "Cancel", 100, function() picker:Hide() end):SetPoint("BOTTOM", picker, "BOTTOM", 0, 8)
        picker.buttons = {}
        for i = 1, GRID * GRID do
            local button = CreateFrame("Button", nil, picker)
            button:SetSize(40, 40)
            button:SetPoint("TOPLEFT", picker, "TOPLEFT", 12 + ((i - 1) % GRID) * CELL, -12 - math.floor((i - 1) / GRID) * CELL)
            button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
            button.texture = button:CreateTexture(nil, "ARTWORK")
            button.texture:SetAllPoints(button)
            button:SetScript("OnClick", function()
                ns.Rec(picker.slot).icon = button.path
                picker:Hide()
                ns.Refresh()
            end)
            picker.buttons[i] = button
        end
    end
    provider = CreateAndInitFromMixin(IconDataProviderMixin, IconDataProviderExtraType.Spellbook)
    picker.slot, picker.first = slot, 1
    Fill()
    picker:Show()
end

-- The Edit menu (API.md, Menus and dropdowns): Rename, Icon, and the action bars as radio entries.
local function Edit(button, slot)
    MenuUtil.CreateContextMenu(button, function(_, root)
        root:CreateTitle(ns.Name(slot))
        root:CreateButton("Rename", function() ns.AskName(slot) end)
        root:CreateButton("Icon", function() Pick(slot) end)
        local names = ns.Names()
        if not names then return end
        local sub = root:CreateButton("Action bars")
        local function choice(label, name)
            sub:CreateRadio(label, function() return (BrainwasherDB[slot] and BrainwasherDB[slot].bars) == name end,
                function() ns.Rec(slot).bars = name; ns.Refresh() end)
        end
        choice("None")
        for _, name in ipairs(names) do choice(name, name) end
    end)
end

-- The rows ------------------------------------------------------------------
local function Row(slot)
    local row = CreateFrame("Frame", nil, panel)
    row.slot = slot
    row:SetSize(300, 40)
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(slot - 1) * 44)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function() if ns.menu.act[slot] then Tip(row) end end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.button = CreateFrame("Button", nil, row)
    row.button:SetSize(32, 32)
    row.button:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    row.button:SetScript("OnClick", function() ns.Activate(slot) end)
    row.icon = row.button:CreateTexture(nil, "ARTWORK")
    row.icon:SetAllPoints(row.button)
    row.name = Text(row, "GameFontHighlightSmall", 118)
    row.name:SetPoint("TOPLEFT", row.button, "TOPRIGHT", 8, -1)
    row.active = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.active:SetPoint("TOPLEFT", row.name, "TOPRIGHT", 4, 0)
    row.active:SetText("Active")
    row.active:SetTextColor(0.3, 1, 0.3)
    row.summary = Text(row, "GameFontDisableSmall", 160)
    row.summary:SetPoint("BOTTOMLEFT", row.button, "BOTTOMRIGHT", 8, 1)
    row.save = Button(row, "Save", 44, function() ns.Save(slot) end)
    row.save:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.edit = Button(row, "Edit", 44, function() Edit(row.edit, slot) end)
    row.edit:SetPoint("RIGHT", row.save, "LEFT", -2, 0)
    rows[slot] = row
    return row
end

local function Update(row, slot, active)
    local buy, owned, split = ns.menu.buy[slot], ns.menu.act[slot], ns.menu.split[slot]
    local bars, missing = Bars(slot)
    local summary = ""
    if split then summary = Colored(split) end
    if bars then summary = summary .. (split and "  " or "") .. "Bars: " .. (missing and "|cffff4d4dmissing|r" or bars) end
    row.active:SetShown(active)
    row.save:SetShown(ns.menu.save[slot])
    row.edit:SetShown(owned)
    row.button:SetEnabled(buy or owned)
    row.summary:SetText(owned and summary or "")
    row.name:SetTextColor(1, 1, 1)
    if buy then
        row.icon:SetTexture(ICONS .. "INV_Misc_Coin_01")
        row.name:SetText("Buy slot " .. slot .. " (" .. buy.price .. "g)")
        row.name:SetTextColor(1, 0.8, 0)
    elseif owned then
        row.icon:SetTexture(Icon(slot))
        row.name:SetText(ns.Name(slot))
    else
        row.icon:SetTexture(QUESTION)
        row.name:SetText("Empty talent slot")
        row.name:SetTextColor(0.6, 0.6, 0.6)
    end
    row:Show()
end

function ns.Refresh()
    if not ns.menu then return end
    local active = ns.Active()
    for slot = 1, math.max(ns.menu.slots, #rows) do
        if slot <= ns.menu.slots then Update(rows[slot] or Row(slot), slot, slot == active) else rows[slot]:Hide() end
    end
    local price = ns.menu.reset and ns.menu.reset.price
    panel.reset:SetText(price and ("Reset talents (" .. price .. ")") or "Reset talents")
    panel.reset:SetShown(ns.menu.reset)
end

-- The panel stands over the stock greeting list (FrameXML GossipFrame.xml: 300 x 334 at
-- 23, -81), which it hides; Goodbye, the close button and Escape stay the game's.
function ns.Show()
    if not panel then
        panel = CreateFrame("Frame", "BrainwasherPanel", GossipFrame)
        panel:SetSize(300, 334)
        panel:SetPoint("TOPLEFT", GossipFrame, "TOPLEFT", 23, -81)
        panel:SetScript("OnHide", function() GossipGreetingScrollFrame:Show(); ns.Leave() end)
        panel.reset = Button(panel, "Reset talents", 140, ns.Reset)
        panel.reset:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 4, 0)
        Button(panel, "Show original", 140, function() panel:Hide() end):SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 0)
    end
    GossipGreetingScrollFrame:Hide()
    panel:Show()
    ns.Refresh()
end

function ns.Hide()
    if panel and panel:IsShown() then panel:Hide() end
end
