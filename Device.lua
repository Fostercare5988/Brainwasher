-- Brainwasher: what the Goblin Brainwashing Device does. It reads the device's gossip menu,
-- tells which slot is active, asks before each action and loads the slot's
-- ActionBars profile once a swap is over. Panel.lua draws it.
local _, ns = ...
BrainwasherDB = BrainwasherDB or {} -- restored first: LoadSavedVariablesFirst

local SETTLE, GIVE_UP = 1.5, 60 -- seconds without talent events; the longest wait for a swap to start
local SWAP_EVENTS = { "CHARACTER_POINTS_CHANGED", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED" }
local POPUPS = { "BRAINWASHER_LOAD", "BRAINWASHER_SAVE", "BRAINWASHER_BUY", "BRAINWASHER_RESET", "BRAINWASHER_RENAME" }
local frame = CreateFrame("Frame")
local session, swap, token = 0 -- a popup of an older menu does nothing; the swap watched; its timer

local function Print(text) DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Brainwasher:|r " .. text) end

function ns.Rec(slot)
    BrainwasherDB[slot] = BrainwasherDB[slot] or {}
    return BrainwasherDB[slot]
end

function ns.Name(slot) return BrainwasherDB[slot] and BrainwasherDB[slot].name or ("Spec " .. slot) end

-- ActionBars is optional (nil without it) and read when used, never cached.
function ns.Names()
    if type(ActionBars) == "table" then return ActionBars.GetProfileNames() end -- vanillaforge-ignore: K1
end

function ns.HasProfile(name)
    for _, known in ipairs(ns.Names() or {}) do
        if known == name then return true end
    end
end

-- A build is every talent's rank, one digit each, trees joined by "-": two slots with
-- one split (41/10/0 twice) differ only here.
local function Build()
    local trees = {}
    for tab = 1, 3 do
        local ranks = {}
        for i = 1, GetNumTalents(tab) do
            local _, _, _, _, rank = GetTalentInfo(tab, i)
            ranks[i] = rank or 0
        end
        trees[tab] = table.concat(ranks)
    end
    return table.concat(trees, "-")
end

local function Split(build)
    local split = {}
    for tree in string.gmatch(build .. "-", "(%d*)%-") do
        local points = 0
        for rank in string.gmatch(tree, "%d") do points = points + rank end
        split[#split + 1] = points
    end
    return split
end

local function SameSplit(a, b) return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end

-- GAP: no talent-group API on this server (GetNumTalentGroups, GetActiveTalentGroup, the
-- groups' talents, SetActiveTalentGroup). The slots, splits and prices are the device's
-- option texts, read in play on OctoWoW 2026-10-21; no other NPC has them.
local function ReadMenu()
    local menu, device = { slots = 0, save = {}, act = {}, split = {}, buy = {} }, false
    for _, o in ipairs(C_GossipInfo.GetOptions()) do
        local text = o.name or ""
        local save = string.match(text, "Save (%d+).. Specialization")
        local act = string.match(text, "Activate (%d+).. Specialization")
        local buy, price = string.match(text, "Buy (%d+).. Specialization.* (%d+) gold")
        local slot = tonumber(save or act or buy)
        if slot and slot >= 1 then
            device = true
            menu.slots = math.max(menu.slots, slot)
            if save then menu.save[slot] = o.gossipOptionID end
            if act then
                menu.act[slot] = o.gossipOptionID
                local a, b, c = string.match(text, "%((%d+)/(%d+)/(%d+)%)")
                menu.split[slot] = a and { tonumber(a), tonumber(b), tonumber(c) }
            end
            if buy then menu.buy[slot] = { id = o.gossipOptionID, price = tonumber(price) or 0 } end
        elseif string.find(text, "Reset my talents") then
            local g, s, c = string.match(text, "%((%d+)g(%d+)s(%d+)c%)")
            local copper = g and g * 10000 + s * 100 + c or 0
            menu.reset = { id = o.gossipOptionID, price = copper > 0 and GetCoinTextureString(copper) or nil }
        end
    end
    if device then return menu end
end

-- The active slot: the one last saved or activated here while it holds your talents, else
-- the only slot that does (a build is exact, a split is not).
function ns.Active()
    local build, current = Build(), BrainwasherDB.current
    local split, menu, exact, exacts, loose, looses = Split(build), ns.menu, nil, 0, nil, 0
    local function holds(slot)
        local rec = BrainwasherDB[slot]
        if rec and rec.build then return rec.build == build end
        return split[1] + split[2] + split[3] > 0 and SameSplit(menu.split[slot], split)
    end
    if current and menu.act[current] and holds(current) then return current end
    for slot in pairs(menu.act) do
        if BrainwasherDB[slot] and BrainwasherDB[slot].build then
            if holds(slot) then exact, exacts = slot, exacts + 1 end
        elseif holds(slot) then
            loose, looses = slot, looses + 1
        end
    end
    if exacts == 1 then return exact end
    if exacts == 0 and looses == 1 then return loose end
end

-- Popups ------------------------------------------------------------------
local function Ask(text)
    return {
        text = text, button1 = YES, button2 = NO, timeout = 0, whileDead = 1, hideOnEscape = 1,
        OnAccept = function(data) if data[1] == session and ns.menu then data[2]() end end,
    }
end
StaticPopupDialogs.BRAINWASHER_LOAD = Ask("Activate %s? This causes a brainwasher debuff.")
StaticPopupDialogs.BRAINWASHER_SAVE = Ask("Save your current talents to %s?")
StaticPopupDialogs.BRAINWASHER_BUY = Ask("Buy talent slot %s for %s gold?")
StaticPopupDialogs.BRAINWASHER_RESET = Ask("Reset all your talents%s? This causes a debuff.")

local function Confirm(which, a1, a2, action) StaticPopup_Show(which, a1, a2, { session, action }) end

-- The stock edit-box popup (FrameXML StaticPopup.lua NAME_CHAT): `this` is the Accept
-- button or the edit box; its parent is the dialog.
local function Rename(data)
    local name = _G[this:GetParent():GetName() .. "EditBox"]:GetText()
    if data[1] == session and ns.menu and name ~= "" then
        ns.Rec(data[2]).name = name
        ns.Refresh()
    end
end
StaticPopupDialogs.BRAINWASHER_RENAME = {
    text = "Name this spec:", button1 = ACCEPT, button2 = CANCEL, hasEditBox = 1, maxLetters = 20,
    timeout = 0, whileDead = 1, hideOnEscape = 1, OnAccept = Rename,
    OnShow = function(data)
        _G[this:GetName() .. "EditBox"]:SetText(ns.Name(data[2]))
        _G[this:GetName() .. "EditBox"]:HighlightText()
    end,
    EditBoxOnEnterPressed = function(data) Rename(data); this:GetParent():Hide() end,
    EditBoxOnEscapePressed = function() this:GetParent():Hide() end,
}

function ns.AskName(slot) StaticPopup_Show("BRAINWASHER_RENAME", nil, nil, { session, slot }) end

-- The swap ----------------------------------------------------------------
local function Stop()
    swap = nil
    for _, e in ipairs(SWAP_EVENTS) do frame:UnregisterEvent(e) end
end

-- Over: the slot holds the talents you have, and its bars load (after combat, if fighting).
local function Finish(mine)
    if not swap or mine ~= token then return end
    ns.Rec(swap.slot).build = Build()
    BrainwasherDB.current = swap.slot
    if swap.bars and UnitAffectingCombat("player") then
        swap.waiting = true
        return
    end
    local bars = swap.bars
    Stop()
    if bars then ActionBars.LoadProfile(bars) end -- vanillaforge-ignore: K1
end

-- GAP: no event says a talent swap is over (an ACTIVE_TALENT_GROUP_CHANGED, or one event
-- when the server's batch of talent changes ends). It is over SETTLE seconds after the
-- last talent or spell event (measured in play, 2026-10-22).
local function Settle()
    token = (token or 0) + 1
    local mine = token
    C_Timer.After(SETTLE, function() Finish(mine) end)
    return mine
end

local function Watch(slot, bars)
    local watch = { slot = slot, bars = bars, before = Build() }
    swap = watch
    for _, e in ipairs(SWAP_EVENTS) do frame:RegisterEvent(e) end
    if BrainwasherDB[slot] and BrainwasherDB[slot].build == watch.before then
        watch.changed = true -- it holds these talents already: nothing will change
        return Settle()
    end
    C_Timer.After(GIVE_UP, function()
        if swap ~= watch or watch.changed then return end
        if Build() ~= watch.before then -- changed without an event
            watch.changed = true
            Finish(Settle())
        else
            Stop()
            if bars then Print("Talents did not change, so action bars were left as they are.") end
        end
    end)
end

-- A swap keeps the points, so CHARACTER_POINTS_CHANGED may not come: a changed build counts too.
local function Swapped(pointsChanged)
    if swap and (swap.changed or pointsChanged or Build() ~= swap.before) then
        swap.changed = true
        Settle()
    end
end

-- Actions -----------------------------------------------------------------
function ns.Activate(slot)
    local menu = ns.menu
    local buy, id = menu.buy[slot], menu.act[slot]
    if buy then
        return Confirm("BRAINWASHER_BUY", slot, buy.price, function() C_GossipInfo.SelectOption(buy.id) end)
    elseif not id then
        return
    elseif ns.Active() == slot then
        return Print(ns.Name(slot) .. " is already active.")
    end
    Confirm("BRAINWASHER_LOAD", ns.Name(slot), nil, function()
        C_GossipInfo.SelectOption(id)
        local bars = ns.Names() and BrainwasherDB[slot] and BrainwasherDB[slot].bars
        if bars and not ns.HasProfile(bars) then
            Print("Action bar profile \"" .. bars .. "\" no longer exists, so bars were left as they are.")
            bars = nil
        end
        Watch(slot, bars)
    end)
end

function ns.Save(slot)
    local id = ns.menu.save[slot]
    local target = ns.menu.act[slot] and (ns.Name(slot) .. ", replacing what it holds") or ("slot " .. slot)
    Confirm("BRAINWASHER_SAVE", target, nil, function()
        C_GossipInfo.SelectOption(id)
        ns.Rec(slot).build = Build()
        BrainwasherDB.current = slot
        ns.Refresh()
    end)
end

function ns.Reset()
    local reset = ns.menu.reset
    Confirm("BRAINWASHER_RESET", reset.price and (" for " .. reset.price) or "", nil, function()
        C_GossipInfo.SelectOption(reset.id)
    end)
end

-- Ends the menu: later answers to its popups do nothing.
function ns.Leave()
    ns.menu = nil
    session = session + 1
    for _, which in ipairs(POPUPS) do StaticPopup_Hide(which) end
end

frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("GOSSIP_CLOSED")
frame:SetScript("OnEvent", function(self, event)
    if event == "GOSSIP_SHOW" then
        ns.Hide()
        local menu = ReadMenu()
        if menu then
            -- The device's split is the truth: a build with another split was saved over from its own menu.
            for slot, split in pairs(menu.split) do
                local rec = BrainwasherDB[slot]
                if rec and rec.build and not SameSplit(Split(rec.build), split) then rec.build = nil end
            end
            ns.menu = menu
            ns.Show()
        end
    elseif event == "GOSSIP_CLOSED" then
        ns.Hide()
        ns.Leave()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if swap and swap.waiting then Finish(token) end
    else
        Swapped(event == "CHARACTER_POINTS_CHANGED")
    end
end)
