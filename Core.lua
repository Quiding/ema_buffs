local addonName, ns = ...
-- Official EMA Module initialization
local EMA_Buffs = LibStub("AceAddon-3.0"):NewAddon("EMA_Buffs", "Module-1.0", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
ns.EMA_Buffs = EMA_Buffs

EMA_Buffs.moduleName = "EMA_Buffs"
EMA_Buffs.settingsDatabaseName = "EMA_BuffsProfileDB"
EMA_Buffs.chatCommand = "ebf"

-- Common buff IDs
ns.warmupIDs = {
    16166, 16188, 16190, 2825, 32182, -- Shaman
    31884, 642, 633, 1044, 1022, -- Paladin
    22812, 29166, 17116, 16689, -- Druid
    10060, 14751, 15487, 10890, -- Priest
}

function EMA_Buffs:GetConfiguration()
    return {
        name = "Buffs", handler = self, type = 'group',
        args = {
            showBars = { type = "toggle", name = "Show Buff Bars", get = "EMAConfigurationGetSetting", set = "EMAConfigurationSetSetting" },
        },
    }
end

-- [charKey][buffName] = { count, duration, expirationTime, icon }
EMA_Buffs.activeBuffs = {}

local L = LibStub("AceLocale-3.0"):GetLocale("Core")
local EMAUtilities = LibStub:GetLibrary("EbonyUtilities-1.0")

EMA_Buffs.parentDisplayName = "Class"
EMA_Buffs.moduleDisplayName = "Buffs"
EMA_Buffs.moduleIcon = "Interface\\Addons\\EMA\\Media\\SettingsIcon.tga"
EMA_Buffs.moduleOrder = 12

_G["BINDING_HEADER_EMABUFFS"] = "EMA Buffs"

EMA_Buffs.settings = {
    profile = {
        showBars = true,
        barScale = 1.0,
        barAlpha = 1.0,
        lockBars = false,
        barOrder = "RoleAsc",
        showNames = true,
        -- Integration
        integrateWithCooldowns = false,
        integratePosition = "Right",
        -- Opacity
        runningAlpha = 0.3,
        missingAlpha = 0.2,
        -- Glow
        glowIfMissing = false,
        glowAnimated = false,
        glowColorR = 1.0, glowColorG = 0.0, glowColorB = 0.0, glowColorA = 1.0,
        -- Frame Styles
        frameBorderStyle = "Blizzard Tooltip",
        frameBackgroundStyle = "Blizzard Dialog Background",
        frameBackgroundColourR = 0.1, frameBackgroundColourG = 0.1, frameBackgroundColourB = 0.1, frameBackgroundColourA = 0.7,
        frameBorderColourR = 0.5, frameBorderColourG = 0.5, frameBorderColourB = 0.5, frameBorderColourA = 1.0,
        -- Bar Styles
        barBorderStyle = "Blizzard Tooltip",
        barBackgroundStyle = "Blizzard Dialog Background",
        barBackgroundColourR = 0.1, barBackgroundColourG = 0.1, barBackgroundColourB = 0.1, barBackgroundColourA = 0.7,
        barBorderColourR = 0.5, barBorderColourG = 0.5, barBorderColourB = 0.5, barBorderColourA = 1.0,
        
        fontStyle = "Arial Narrow",
        fontSize = 12,
        iconSize = 30,
        iconMargin = 2,
        barMargin = 4,
        stackFontSize = 16,
        stackColorR = 1.0, stackColorG = 1.0, stackColorB = 0.0,
        enabledMembers = {},
        trackedBuffs = {
            ["WARRIOR"] = {}, ["PALADIN"] = {}, ["HUNTER"] = {}, ["ROGUE"] = {},
            ["PRIEST"] = {}, ["DEATHKNIGHT"] = {}, ["SHAMAN"] = {}, ["MAGE"] = {},
            ["WARLOCK"] = {}, ["DRUID"] = {},
        },
        teamBarsPos = { point = "CENTER", x = -200, y = 0 },
    }
}

function EMA_Buffs:OnInitialize()
    self.completeDatabase = LibStub("AceDB-3.0"):New(self.settingsDatabaseName, self.settings)
    self.db = self.completeDatabase.profile
    self.characterName = UnitName("player")
    self:SettingsCreate()
    self:RegisterChatCommand("ebf", "ChatCommand")
    self:RegisterChatCommand("ema-buffs", "ChatCommand")
    local _, englishClass = UnitClass("player")
    self.selectedClass = englishClass
    self:SettingsRefresh()
    for _, id in ipairs(ns.warmupIDs) do GetSpellInfo(id) end
end

function EMA_Buffs:GetSpellInfoRobust(search)
    if not search or search == "" then return nil end
    local name, icon, spellID
    if tonumber(search) then
        name, _, icon, _, _, _, spellID = GetSpellInfo(tonumber(search))
        if name then return name, icon, spellID end
    end
    name, _, icon, _, _, _, spellID = GetSpellInfo(search)
    if name then return name, icon, spellID end
    local searchLower = search:lower()
    for i = 1, 100000 do
        local n = GetSpellInfo(i)
        if n and n:lower() == searchLower then
            name, _, icon, _, _, _, spellID = GetSpellInfo(i)
            return name, icon, spellID
        end
    end
    return nil
end

function EMA_Buffs:ChatCommand(input)
    local cmd = input and input:trim():lower() or ""
    if cmd == "config" then self:EMAChatCommand("config")
    else self:Print("Usage: /ebf config") end
end

function EMA_Buffs:OnEnable()
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "ScanAndRefresh")
    self:RegisterEvent("PLAYER_LOGIN", "ScanAndRefresh")
    if EMAApi then
        self:RegisterMessage( EMAApi.MESSAGE_CHARACTER_ONLINE, "ScanAndRefresh" )
        self:RegisterMessage( EMAApi.MESSAGE_CHARACTER_OFFLINE, "ScanAndRefresh" )
    end
    if ns.UI then ns.UI:Initialize() end
    self:ScheduleRepeatingTimer("ScanAndRefresh", 2.0)
end

function EMA_Buffs:ScanAndRefresh()
    self:ScanAllUnits()
    if ns.UI then ns.UI:RefreshBars() end
end

function EMA_Buffs:UNIT_AURA(event, unit)
    if not unit then return end
    local name = GetUnitName(unit, true)
    if name and EMAApi.IsCharacterInTeam(name) then
        self:ScanUnit(unit)
    end
end

function EMA_Buffs:ScanAllUnits()
    self:ScanUnit("player")
    for i = 1, 4 do self:ScanUnit("party"..i) end
    if IsInRaid() then
        for i = 1, 40 do self:ScanUnit("raid"..i) end
    end
end

function EMA_Buffs:ScanUnit(unit)
    local characterName = GetUnitName(unit, true)
    if not characterName or not EMAApi.IsCharacterInTeam(characterName) then return end
    local charKey = Ambiguate(characterName, "none"):lower()
    local class, _ = EMAApi.GetClass(characterName)
    local classKey = class and class:upper() or "SHAMAN"
    local tracked = self.db.trackedBuffs[classKey]
    if not tracked then return end

    self.activeBuffs[charKey] = self.activeBuffs[charKey] or {}
    local foundThisScan = {}

    for i = 1, 40 do
        local name, icon, count, _, duration, expirationTime = UnitBuff(unit, i)
        if not name then break end
        
        for _, buffInfo in ipairs(tracked) do
            if buffInfo.name == name then
                self.activeBuffs[charKey][name] = {
                    count = count or 0,
                    duration = duration or 0,
                    expirationTime = expirationTime or 0,
                    icon = icon
                }
                foundThisScan[name] = true
            end
        end
    end

    for buffName, _ in pairs(self.activeBuffs[charKey]) do
        if not foundThisScan[buffName] then
            self.activeBuffs[charKey][buffName] = nil
        end
    end
    
    if ns.UI then ns.UI:UpdateUI() end
end

function EMA_Buffs:PushSettingsToTeam() self:EMASendSettings() end

function EMA_Buffs:EMAOnSettingsReceived(characterName, settings)
    if characterName ~= self.characterName then
        EMAUtilities:CopyTable(self.db, settings)
        self:SettingsRefresh()
        ns.UI:RefreshBars()
    end
end

function EMA_Buffs:OnEMAProfileChanged()
    if self.completeDatabase then self.db = self.completeDatabase.profile end
    self:SettingsRefresh()
    ns.UI:RefreshBars()
end

function EMA_Buffs:SettingsCreate()
    self.settingsControl = {}
    self.settingsControlClass = {}
    local EMAHelperSettings = LibStub("EMAHelperSettings-1.0")
    EMAHelperSettings:CreateSettings(self.settingsControlClass, "Class", "Class", function() end, "Interface\\AddOns\\EMA\\Media\\TeamCore.tga", 5)
    EMAHelperSettings:CreateSettings(self.settingsControl, "Buffs", "Class", function() self:SettingsRefresh() end, "Interface\\AddOns\\EMA\\Media\\SettingsIcon.tga", 12)
    
    local top, left = EMAHelperSettings:TopOfSettings(), EMAHelperSettings:LeftOfSettings()
    local headingHeight, headingWidth = EMAHelperSettings:HeadingHeight(), EMAHelperSettings:HeadingWidth(true)
    local checkBoxHeight, sliderHeight = EMAHelperSettings:GetCheckBoxHeight(), EMAHelperSettings:GetSliderHeight()
    local dropdownHeight, verticalSpacing = EMAHelperSettings:GetDropdownHeight(), EMAHelperSettings:GetVerticalSpacing()
    local movingTop = top
    
    EMAHelperSettings:CreateHeading(self.settingsControl, "General Options", movingTop, false)
    movingTop = movingTop - headingHeight
    self.settingsControl.checkBoxShowBars = EMAHelperSettings:CreateCheckBox(self.settingsControl, headingWidth, left, movingTop, "Show Buff Bars", function(w, e, v) self.db.showBars = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - checkBoxHeight
    self.settingsControl.checkBoxLockBars = EMAHelperSettings:CreateCheckBox(self.settingsControl, headingWidth, left, movingTop, "Lock Bars (Alt-Click to move)", function(w, e, v) self.db.lockBars = v; self:SettingsRefresh() end)
    movingTop = movingTop - checkBoxHeight
    self.settingsControl.checkBoxShowNames = EMAHelperSettings:CreateCheckBox(self.settingsControl, headingWidth, left, movingTop, "Show Character Names", function(w, e, v) self.db.showNames = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - checkBoxHeight
    
    self.settingsControl.checkBoxIntegrate = EMAHelperSettings:CreateCheckBox(self.settingsControl, headingWidth, left, movingTop, "Integrate into Cooldowns bar", function(w, e, v) self.db.integrateWithCooldowns = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - checkBoxHeight
    self.settingsControl.dropdownIntegratePos = EMAHelperSettings:CreateDropdown(self.settingsControl, headingWidth, left, movingTop, "Integration Position")
    self.settingsControl.dropdownIntegratePos:SetList({ ["Left"] = "Left of Cooldowns", ["Right"] = "Right of Cooldowns" })
    self.settingsControl.dropdownIntegratePos:SetCallback("OnValueChanged", function(w, e, v) self.db.integratePosition = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - dropdownHeight - verticalSpacing

    self.settingsControl.sliderScale = EMAHelperSettings:CreateSlider(self.settingsControl, headingWidth, left, movingTop, "Overall Scale")
    self.settingsControl.sliderScale:SetSliderValues(0.5, 2.0, 0.01)
    self.settingsControl.sliderScale:SetCallback("OnValueChanged", function(w, e, v) self.db.barScale = tonumber(v); ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - sliderHeight
    self.settingsControl.sliderAlpha = EMAHelperSettings:CreateSlider(self.settingsControl, headingWidth, left, movingTop, "Overall Alpha")
    self.settingsControl.sliderAlpha:SetSliderValues(0.1, 1.0, 0.01)
    self.settingsControl.sliderAlpha:SetCallback("OnValueChanged", function(w, e, v) self.db.barAlpha = tonumber(v); ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - sliderHeight
    self.settingsControl.dropdownOrder = EMAHelperSettings:CreateDropdown(self.settingsControl, headingWidth, left, movingTop, "Bar Order")
    self.settingsControl.dropdownOrder:SetList({ ["NameAsc"] = "Name (Asc)", ["NameDesc"] = "Name (Desc)", ["EMAPosition"] = "EMA Team Order", ["RoleAsc"] = "Role (Tank > Healer > DPS)" })
    self.settingsControl.dropdownOrder:SetCallback("OnValueChanged", function(w, e, v) self.db.barOrder = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - dropdownHeight - verticalSpacing

    EMAHelperSettings:CreateHeading(self.settingsControl, "Missing Buff Highlights", movingTop, false)
    movingTop = movingTop - headingHeight
    self.settingsControl.checkBoxGlow = EMAHelperSettings:CreateCheckBox(self.settingsControl, headingWidth, left, movingTop, "Glow if missing", function(w, e, v) self.db.glowIfMissing = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - checkBoxHeight
    self.settingsControl.checkBoxGlowAnimated = EMAHelperSettings:CreateCheckBox(self.settingsControl, headingWidth, left, movingTop, "Glow Animation", function(w, e, v) self.db.glowAnimated = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - checkBoxHeight
    self.settingsControl.colorGlow = EMAHelperSettings:CreateColourPicker(self.settingsControl, headingWidth, left, movingTop, "Glow Color")
    self.settingsControl.colorGlow:SetCallback("OnValueChanged", function(w, e, r, g, b, a) self.db.glowColorR, self.db.glowColorG, self.db.glowColorB, self.db.glowColorA = r, g, b, a; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 30

    EMAHelperSettings:CreateHeading(self.settingsControl, "Opacity Settings", movingTop, false)
    movingTop = movingTop - headingHeight
    self.settingsControl.sliderRunningAlpha = EMAHelperSettings:CreateSlider(self.settingsControl, headingWidth, left, movingTop, "Timer Running Opacity")
    self.settingsControl.sliderRunningAlpha:SetSliderValues(0.1, 1.0, 0.01)
    self.settingsControl.sliderRunningAlpha:SetCallback("OnValueChanged", function(w, e, v) self.db.runningAlpha = tonumber(v); ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - sliderHeight
    self.settingsControl.sliderMissingAlpha = EMAHelperSettings:CreateSlider(self.settingsControl, headingWidth, left, movingTop, "Buff Missing Opacity")
    self.settingsControl.sliderMissingAlpha:SetSliderValues(0.1, 1.0, 0.01)
    self.settingsControl.sliderMissingAlpha:SetCallback("OnValueChanged", function(w, e, v) self.db.missingAlpha = tonumber(v); ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - sliderHeight

    EMAHelperSettings:CreateHeading(self.settingsControl, "Appearance: Whole UI Frame", movingTop, false)
    movingTop = movingTop - headingHeight
    self.settingsControl.dropdownFrameBorder = EMAHelperSettings:CreateMediaBorder(self.settingsControl, headingWidth, left, movingTop, "UI Border Style")
    self.settingsControl.dropdownFrameBorder:SetCallback("OnValueChanged", function(w, e, v) self.db.frameBorderStyle = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 110
    self.settingsControl.dropdownFrameBackground = EMAHelperSettings:CreateMediaBackground(self.settingsControl, headingWidth, left, movingTop, "UI Background Style")
    self.settingsControl.dropdownFrameBackground:SetCallback("OnValueChanged", function(w, e, v) self.db.frameBackgroundStyle = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 110
    self.settingsControl.colorFrameBackground = EMAHelperSettings:CreateColourPicker(self.settingsControl, headingWidth, left, movingTop, "UI Background Color")
    self.settingsControl.colorFrameBackground:SetCallback("OnValueChanged", function(w, e, r, g, b, a) self.db.frameBackgroundColourR, self.db.frameBackgroundColourG, self.db.frameBackgroundColourB, self.db.frameBackgroundColourA = r, g, b, a; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 30
    self.settingsControl.colorFrameBorder = EMAHelperSettings:CreateColourPicker(self.settingsControl, headingWidth, left, movingTop, "UI Border Color")
    self.settingsControl.colorFrameBorder:SetCallback("OnValueChanged", function(w, e, r, g, b, a) self.db.frameBorderColourR, self.db.frameBorderColourG, self.db.frameBorderColourB, self.db.frameBorderColourA = r, g, b, a; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 30

    EMAHelperSettings:CreateHeading(self.settingsControl, "Appearance: Individual Bars", movingTop, false)
    movingTop = movingTop - headingHeight
    self.settingsControl.dropdownBarBorder = EMAHelperSettings:CreateMediaBorder(self.settingsControl, headingWidth, left, movingTop, "Bar Border Style")
    self.settingsControl.dropdownBarBorder:SetCallback("OnValueChanged", function(w, e, v) self.db.barBorderStyle = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 110
    self.settingsControl.dropdownBarBackground = EMAHelperSettings:CreateMediaBackground(self.settingsControl, headingWidth, left, movingTop, "Bar Background Style")
    self.settingsControl.dropdownBarBackground:SetCallback("OnValueChanged", function(w, e, v) self.db.barBackgroundStyle = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 110
    self.settingsControl.colorBarBackground = EMAHelperSettings:CreateColourPicker(self.settingsControl, headingWidth, left, movingTop, "Bar Background Color")
    self.settingsControl.colorBarBackground:SetCallback("OnValueChanged", function(w, e, r, g, b, a) self.db.barBackgroundColourR, self.db.barBackgroundColourG, self.db.barBackgroundColourB, self.db.barBackgroundColourA = r, g, b, a; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 30
    self.settingsControl.colorBarBorder = EMAHelperSettings:CreateColourPicker(self.settingsControl, headingWidth, left, movingTop, "Bar Border Color")
    self.settingsControl.colorBarBorder:SetCallback("OnValueChanged", function(w, e, r, g, b, a) self.db.barBorderColourR, self.db.barBorderColourG, self.db.barBorderColourB, self.db.barBorderColourA = r, g, b, a; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 30

    EMAHelperSettings:CreateHeading(self.settingsControl, "Sizing & Spacing", movingTop, false)
    movingTop = movingTop - headingHeight
    self.settingsControl.sliderIconSize = EMAHelperSettings:CreateSlider(self.settingsControl, headingWidth, left, movingTop, "Icon Size")
    self.settingsControl.sliderIconSize:SetSliderValues(16, 64, 1)
    self.settingsControl.sliderIconSize:SetCallback("OnValueChanged", function(w, e, v) self.db.iconSize = tonumber(v); ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - sliderHeight
    self.settingsControl.sliderIconMargin = EMAHelperSettings:CreateSlider(self.settingsControl, headingWidth, left, movingTop, "Icon Spacing")
    self.settingsControl.sliderIconMargin:SetSliderValues(0, 20, 1)
    self.settingsControl.sliderIconMargin:SetCallback("OnValueChanged", function(w, e, v) self.db.iconMargin = tonumber(v); ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - sliderHeight
    self.settingsControl.sliderBarMargin = EMAHelperSettings:CreateSlider(self.settingsControl, headingWidth, left, movingTop, "Bar Spacing")
    self.settingsControl.sliderBarMargin:SetSliderValues(0, 50, 1)
    self.settingsControl.sliderBarMargin:SetCallback("OnValueChanged", function(w, e, v) self.db.barMargin = tonumber(v); ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - sliderHeight

    EMAHelperSettings:CreateHeading(self.settingsControl, "Text & Stacks", movingTop, false)
    movingTop = movingTop - headingHeight
    self.settingsControl.dropdownFont = EMAHelperSettings:CreateMediaFont(self.settingsControl, headingWidth, left, movingTop, "Font Style")
    self.settingsControl.dropdownFont:SetCallback("OnValueChanged", function(w, e, v) self.db.fontStyle = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 110
    self.settingsControl.sliderStackFontSize = EMAHelperSettings:CreateSlider(self.settingsControl, headingWidth, left, movingTop, "Stack Font Size")
    self.settingsControl.sliderStackFontSize:SetSliderValues(6, 32, 1)
    self.settingsControl.sliderStackFontSize:SetCallback("OnValueChanged", function(w, e, v) self.db.stackFontSize = tonumber(v); ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - sliderHeight
    self.settingsControl.colorStack = EMAHelperSettings:CreateColourPicker(self.settingsControl, headingWidth, left, movingTop, "Stack Color")
    self.settingsControl.colorStack:SetCallback("OnValueChanged", function(w, e, r, g, b, a) self.db.stackColorR, self.db.stackColorG, self.db.stackColorB = r, g, b; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 30

    EMAHelperSettings:CreateHeading(self.settingsControl, "Members List", movingTop, false)
    movingTop = movingTop - headingHeight
    self.settingsControl.memberList = {
        listFrameName = "EMABuffsSettingsMemberListFrame", parentFrame = self.settingsControl.widgetSettings.content, listTop = movingTop, listLeft = left, listWidth = headingWidth, rowHeight = 25, rowsToDisplay = 5, columnsToDisplay = 2,
        columnInformation = {{ width = 70, alignment = "LEFT" }, { width = 30, alignment = "LEFT" }},
        scrollRefreshCallback = function() self:SettingsMemberListScrollRefresh() end, rowClickCallback = function(obj, rowNumber, columnNumber) self:SettingsMemberListRowClick(rowNumber, columnNumber) end
    }
    EMAHelperSettings:CreateScrollList(self.settingsControl.memberList)
    movingTop = movingTop - self.settingsControl.memberList.listHeight - verticalSpacing

    EMAHelperSettings:CreateHeading(self.settingsControl, "Tracked Buffs by Class", movingTop, false)
    movingTop = movingTop - headingHeight
    self.settingsControl.dropdownClass = EMAHelperSettings:CreateDropdown(self.settingsControl, headingWidth, left, movingTop, "Select Class to Manage")
    self.settingsControl.dropdownClass:SetList({
        ["WARRIOR"] = "Warrior", ["PALADIN"] = "Paladin", ["HUNTER"] = "Hunter", ["ROGUE"] = "Rogue",
        ["PRIEST"] = "Priest", ["DEATHKNIGHT"] = "Death Knight", ["SHAMAN"] = "Shaman", ["MAGE"] = "Mage",
        ["WARLOCK"] = "Warlock", ["DRUID"] = "Druid"
    })
    self.settingsControl.dropdownClass:SetCallback("OnValueChanged", function(w, e, v) self.selectedClass = v; self:SettingsSpellListScrollRefresh(); self:SettingsRefresh() end)
    movingTop = movingTop - dropdownHeight - verticalSpacing
    
    self.settingsControl.spellList = {
        listFrameName = "EMABuffsSettingsSpellListFrame", parentFrame = self.settingsControl.widgetSettings.content, listTop = movingTop, listLeft = left, listWidth = headingWidth, rowHeight = 25, rowsToDisplay = 8, columnsToDisplay = 5,
        columnInformation = { { width = 12, alignment = "CENTER" }, { width = 8, alignment = "CENTER" }, { width = 45, alignment = "LEFT" }, { width = 15, alignment = "LEFT" }, { width = 20, alignment = "CENTER" } },
        scrollRefreshCallback = function() self:SettingsSpellListScrollRefresh() end, rowClickCallback = function(obj, rowNumber, columnNumber) self:SettingsSpellListRowClick(rowNumber, columnNumber) end
    }
    EMAHelperSettings:CreateScrollList(self.settingsControl.spellList)
    movingTop = movingTop - self.settingsControl.spellList.listHeight - verticalSpacing
    
    local halfWidth = (headingWidth - 10) / 2
    self.settingsControl.editBoxAddSpell = EMAHelperSettings:CreateEditBox(self.settingsControl, halfWidth, left, movingTop, "Buff Name or ID")
    self.settingsControl.buttonAddSpell = EMAHelperSettings:CreateButton(self.settingsControl, 60, left + headingWidth - 60, movingTop, "Add", function() self:AddSpellToTrackedList() end)
    movingTop = movingTop - EMAHelperSettings:GetEditBoxHeight()

    self:EMAModuleInitialize(self.settingsControl.widgetSettings.frame)
    self.settingsControl.widgetSettings.content:SetHeight(-movingTop + 20)
end

function EMA_Buffs:SettingsRefresh()
    if self.settingsControl and self.db then
        local db = self.db
        local integrated = db.integrateWithCooldowns
        
        self.settingsControl.checkBoxShowBars:SetValue(db.showBars)
        self.settingsControl.checkBoxLockBars:SetValue(db.lockBars)
        self.settingsControl.checkBoxLockBars:SetDisabled(integrated)
        
        self.settingsControl.checkBoxShowNames:SetValue(db.showNames)
        self.settingsControl.checkBoxShowNames:SetDisabled(integrated)
        
        self.settingsControl.checkBoxIntegrate:SetValue(integrated)
        self.settingsControl.dropdownIntegratePos:SetValue(db.integratePosition or "Right")
        self.settingsControl.dropdownIntegratePos:SetDisabled(not integrated)
        
        self.settingsControl.sliderScale:SetValue(db.barScale or 1.0)
        -- self.settingsControl.sliderScale:SetDisabled(integrated)
        
        self.settingsControl.sliderAlpha:SetValue(db.barAlpha or 1.0)
        -- self.settingsControl.sliderAlpha:SetDisabled(integrated)
        
        self.settingsControl.dropdownOrder:SetValue(db.barOrder or "RoleAsc")
        -- self.settingsControl.dropdownOrder:SetDisabled(integrated)
        
        self.settingsControl.sliderRunningAlpha:SetValue(db.runningAlpha or 0.3)
        self.settingsControl.sliderMissingAlpha:SetValue(db.missingAlpha or 0.2)
        
        self.settingsControl.checkBoxGlow:SetValue(db.glowIfMissing)
        self.settingsControl.checkBoxGlowAnimated:SetValue(db.glowAnimated)
        self.settingsControl.checkBoxGlowAnimated:SetDisabled(not db.glowIfMissing)
        self.settingsControl.colorGlow:SetColor(db.glowColorR or 1, db.glowColorG or 0, db.glowColorB or 0, db.glowColorA or 1)
        self.settingsControl.colorGlow:SetDisabled(not db.glowIfMissing)

        self.settingsControl.dropdownFrameBorder:SetValue(db.frameBorderStyle or "Blizzard Tooltip")
        -- self.settingsControl.dropdownFrameBorder:SetDisabled(integrated)
        
        self.settingsControl.dropdownFrameBackground:SetValue(db.frameBackgroundStyle or "Blizzard Dialog Background")
        -- self.settingsControl.dropdownFrameBackground:SetDisabled(integrated)
        
        self.settingsControl.colorFrameBackground:SetColor(db.frameBackgroundColourR or 0.1, db.frameBackgroundColourG or 0.1, db.frameBackgroundColourB or 0.1, db.frameBackgroundColourA or 0.7)
        -- self.settingsControl.colorFrameBackground:SetDisabled(integrated)
        
        self.settingsControl.colorFrameBorder:SetColor(db.frameBorderColourR or 0.5, db.frameBorderColourG or 0.5, db.frameBorderColourB or 0.5, db.frameBorderColourA or 1.0)
        -- self.settingsControl.colorFrameBorder:SetDisabled(integrated)
        
        self.settingsControl.dropdownBarBorder:SetValue(db.barBorderStyle or "Blizzard Tooltip")
        -- self.settingsControl.dropdownBarBorder:SetDisabled(integrated)
        
        self.settingsControl.dropdownBarBackground:SetValue(db.barBackgroundStyle or "Blizzard Dialog Background")
        -- self.settingsControl.dropdownBarBackground:SetDisabled(integrated)
        
        self.settingsControl.colorBarBackground:SetColor(db.barBackgroundColourR or 0.1, db.barBackgroundColourG or 0.1, db.barBackgroundColourB or 0.1, db.barBackgroundColourA or 0.7)
        -- self.settingsControl.colorBarBackground:SetDisabled(integrated)
        
        self.settingsControl.colorBarBorder:SetColor(db.frameBorderColourR or 0.5, db.frameBorderColourG or 0.5, db.frameBorderColourB or 0.5, db.frameBorderColourA or 1.0)
        -- self.settingsControl.colorBarBorder:SetDisabled(integrated)
        
        self.settingsControl.sliderIconSize:SetValue(db.iconSize or 30)
        -- self.settingsControl.sliderIconSize:SetDisabled(integrated)
        
        self.settingsControl.sliderIconMargin:SetValue(db.iconMargin or 2)
        -- self.settingsControl.sliderIconMargin:SetDisabled(integrated)
        
        self.settingsControl.sliderBarMargin:SetValue(db.barMargin or 4)
        -- self.settingsControl.sliderBarMargin:SetDisabled(integrated)
        
        self.settingsControl.dropdownFont:SetValue(db.fontStyle or "Arial Narrow")
        self.settingsControl.sliderStackFontSize:SetValue(db.stackFontSize or 16)
        self.settingsControl.colorStack:SetColor(db.stackColorR or 1, db.stackColorG or 1, db.stackColorB or 0, 1.0)
        
        self.settingsControl.dropdownClass:SetValue(self.selectedClass)
        self:SettingsMemberListScrollRefresh(); self:SettingsSpellListScrollRefresh()
    end
end

function EMA_Buffs:SettingsMemberListScrollRefresh()
    local team = {}
    for index, characterName in EMAApi.TeamListOrdered() do
        local class, color = EMAApi.GetClass(characterName)
        table.insert(team, { name = characterName, color = color })
    end
    FauxScrollFrame_Update(self.settingsControl.memberList.listScrollFrame, #team, self.settingsControl.memberList.rowsToDisplay, self.settingsControl.memberList.rowHeight)
    local offset = FauxScrollFrame_GetOffset(self.settingsControl.memberList.listScrollFrame)
    for i = 1, self.settingsControl.memberList.rowsToDisplay do
        local row = self.settingsControl.memberList.rows[i]
        local dataIndex = i + offset
        if dataIndex <= #team then
            local info = team[dataIndex]
            local name = info.name
            local color = info.color or {r=1, g=1, b=1}
            local enabled = self.db.enabledMembers[name] ~= false
            row.columns[1].textString:SetText(Ambiguate(name, "short"))
            row.columns[1].textString:SetTextColor(color.r, color.g, color.b)
            row.columns[2].textString:SetText(enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r")
            row.charName = name
            row:Show()
        else row:Hide() end
    end
end

function EMA_Buffs:SettingsMemberListRowClick(rowNumber, columnNumber)
    local offset = FauxScrollFrame_GetOffset(self.settingsControl.memberList.listScrollFrame)
    local team = {}
    for index, characterName in EMAApi.TeamListOrdered() do table.insert(team, characterName) end
    local dataIndex = rowNumber + offset
    if dataIndex <= #team then
        local name = team[dataIndex]
        self.db.enabledMembers[name] = not (self.db.enabledMembers[name] ~= false)
        self:SettingsMemberListScrollRefresh(); ns.UI:RefreshBars(); self:SettingsRefresh()
    end
end

function EMA_Buffs:SettingsSpellListScrollRefresh()
    local class = self.selectedClass
    local spells = class and self.db.trackedBuffs[class] or {}
    local rh = self.settingsControl.spellList.rowHeight
    FauxScrollFrame_Update(self.settingsControl.spellList.listScrollFrame, #spells, self.settingsControl.spellList.rowsToDisplay, rh)
    local offset = FauxScrollFrame_GetOffset(self.settingsControl.spellList.listScrollFrame)
    for i = 1, self.settingsControl.spellList.rowsToDisplay do
        local row = self.settingsControl.spellList.rows[i]
        local dataIndex = i + offset
        if dataIndex <= #spells then
            local spell = spells[dataIndex]
            row.columns[1].textString:SetText("[Up] [Dn]")
            if not row.iconTex then
                row.iconTex = row.columns[2]:CreateTexture(nil, "ARTWORK")
                row.iconTex:SetSize(rh-4, rh-4)
                row.iconTex:SetPoint("CENTER")
                row.iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            row.iconTex:SetTexture(spell.icon)
            row.columns[2].textString:SetText("")
            row.columns[3].textString:SetText(spell.name)
            row.columns[4].textString:SetText("")
            row.columns[5].textString:SetText("Remove")
            row.dataIndex = dataIndex
            row:Show()
        else row:Hide() end
    end
end

function EMA_Buffs:SettingsSpellListRowClick(rowNumber, columnNumber)
    local class = self.selectedClass
    if not class then return end
    local offset = FauxScrollFrame_GetOffset(self.settingsControl.spellList.listScrollFrame)
    local dataIndex = rowNumber + offset
    local spells = self.db.trackedBuffs[class]
    if columnNumber == 1 then
        local x = GetCursorPosition() / UIParent:GetEffectiveScale()
        local mid = self.settingsControl.spellList.rows[rowNumber].columns[1]:GetCenter()
        if x < mid then if dataIndex > 1 then table.insert(spells, dataIndex - 1, table.remove(spells, dataIndex)) end
        else if dataIndex < #spells then table.insert(spells, dataIndex + 1, table.remove(spells, dataIndex)) end end
    elseif columnNumber == 5 then table.remove(spells, dataIndex) end
    self:SettingsSpellListScrollRefresh(); self:PushSettingsToTeam(); self:SettingsRefresh()
end
