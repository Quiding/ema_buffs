local addonName, ns = ...
local EMA_Buffs = ns.EMA_Buffs
local UI = {}
ns.UI = UI

local SharedMedia = LibStub("LibSharedMedia-3.0")

-- UI Utils
local function ApplySkin(f, prefix)
    if not EMA_Buffs.db or not f then return end
    local db = EMA_Buffs.db
    local backgroundFile = SharedMedia:Fetch("background", db[prefix.."BackgroundStyle"])
    local borderFile = SharedMedia:Fetch("border", db[prefix.."BorderStyle"])
    
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = backgroundFile,
            edgeFile = borderFile,
            tile = true, tileSize = 16, edgeSize = 10,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        f:SetBackdropColor(
            db[prefix.."BackgroundColourR"] or 0.1, 
            db[prefix.."BackgroundColourG"] or 0.1, 
            db[prefix.."BackgroundColourB"] or 0.1, 
            db[prefix.."BackgroundColourA"] or 0.7
        )
        f:SetBackdropBorderColor(
            db[prefix.."BorderColourR"] or 0.5, 
            db[prefix.."BorderColourG"] or 0.5, 
            db[prefix.."BorderColourB"] or 0.5, 
            db[prefix.."BorderColourA"] or 1.0
        )
    end
end

local function ApplyFontStyle(textString)
    if not EMA_Buffs.db or not textString then return end
    local db = EMA_Buffs.db
    local fontFile = SharedMedia:Fetch("font", db.fontStyle)
    textString:SetFont(fontFile, db.fontSize, "OUTLINE")
end

-----------------------------------------------------------------------
-- BAR CREATION
-----------------------------------------------------------------------
local function CreateBuffBar(characterName, parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f.characterName = characterName
    f:SetFrameLevel(parent:GetFrameLevel() + 1)

    f.nameLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.nameLabel:SetText(Ambiguate(characterName, "short"))

    f.icons = {}

    f.UpdateLayout = function(self)
        if not EMA_Buffs.db then return end
        local db = EMA_Buffs.db
        
        local charKey = Ambiguate(self.characterName, "none"):lower()
        local class, _ = EMAApi.GetClass(self.characterName)
        local classKey = class and class:upper() or "SHAMAN"
        local tracked = EMA_Buffs.db.trackedBuffs[classKey] or {}
        
        local EMA_Cooldowns = LibStub("AceAddon-3.0"):GetAddon("EMA_Cooldowns", true)
        local integrated = db.integrateWithCooldowns and EMA_Cooldowns and EMA_Cooldowns.db
        
        -- Use Buffs own settings as requested by user ("settings in buffs now doesn't seem to change anything")
        local size = db.iconSize
        local margin = db.iconMargin
        local runningAlpha = db.runningAlpha
        local missingAlpha = db.missingAlpha
        
        for _, iconFrame in ipairs(self.icons) do iconFrame:Hide() end

        local activeCount = 0
        for i, buffInfo in ipairs(tracked) do
            activeCount = i
            if not self.icons[i] then
                local b = CreateFrame("Frame", nil, self, "BackdropTemplate")
                b:SetFrameLevel(self:GetFrameLevel() + 2)
                b:SetBackdrop({
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    edgeSize = 1,
                })
                b:SetBackdropBorderColor(0, 0, 0, 1)
                
                b.icon = b:CreateTexture(nil, "OVERLAY")
                b.icon:SetPoint("TOPLEFT", 1, -1)
                b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
                b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                
                b.glow = b:CreateTexture(nil, "OVERLAY", nil, 7)
                b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
                b.glow:SetBlendMode("ADD")
                b.glow:SetPoint("TOPLEFT", -4, 4)
                b.glow:SetPoint("BOTTOMRIGHT", 4, -4)
                
                b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
                b.cooldown:SetAllPoints(b.icon)
                b.cooldown:SetDrawEdge(false)
                b.cooldown:SetFrameLevel(b:GetFrameLevel() + 1)

                b.stackText = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
                b.stackText:SetPoint("BOTTOMRIGHT", -2, 2)
                
                self.icons[i] = b
            end
            
            local b = self.icons[i]
            b:SetSize(size, size)
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", (i-1)*(size + margin), 4)
            b.icon:SetTexture(buffInfo.icon or 134400)
            
            local LBG = LibStub("LibButtonGlow-1.0", true)
            local activeData = EMA_Buffs.activeBuffs[charKey] and EMA_Buffs.activeBuffs[charKey][buffInfo.name]
            if activeData then
                b.glow:Hide()
                if LBG then LBG.HideOverlayGlow(b) end
                if activeData.duration > 0 and activeData.expirationTime > 0 then
                    b:SetAlpha(runningAlpha or 0.3)
                    b.cooldown:SetCooldown(activeData.expirationTime - activeData.duration, activeData.duration)
                    b.cooldown:Show()
                else
                    b:SetAlpha(1.0)
                    b.cooldown:Hide()
                end
                
                if activeData.count and activeData.count > 1 then
                    local fontFile = SharedMedia:Fetch("font", db.fontStyle)
                    b.stackText:SetFont(fontFile, db.stackFontSize, "OUTLINE")
                    b.stackText:SetTextColor(db.stackColorR or 1, db.stackColorG or 1, db.stackColorB or 0)
                    b.stackText:SetText(activeData.count)
                    b.stackText:Show()
                else
                    b.stackText:Hide()
                end
            else
                b:SetAlpha(missingAlpha or 0.2)
                b.cooldown:Hide()
                b.stackText:Hide()
                if db.glowIfMissing then
                    if db.glowAnimated and LBG then
                        b.glow:Hide()
                        LBG.ShowOverlayGlow(b, {
                            color = { db.glowColorR or 1, db.glowColorG or 0, db.glowColorB or 0, db.glowColorA or 1 },
                        })
                    else
                        if LBG then LBG.HideOverlayGlow(b) end
                        b.glow:SetVertexColor(db.glowColorR or 1, db.glowColorG or 0, db.glowColorB or 0, db.glowColorA or 1)
                        b.glow:Show()
                    end
                else
                    b.glow:Hide()
                    if LBG then LBG.HideOverlayGlow(b) end
                end
            end
            b:Show()
        end

        local totalWidth = (activeCount > 0) and ((size * activeCount) + (margin * (activeCount - 1))) or 0
        self:SetSize(math.max(1, totalWidth), size + 8)

        if not db.integrateWithCooldowns then
            self.nameLabel:Show()
            self.nameLabel:ClearAllPoints()
            self.nameLabel:SetPoint("TOPLEFT", 4, -4)
            ApplySkin(self, "bar")
        else
            self.nameLabel:Hide()
            self:SetBackdrop(nil)
        end
        ApplyFontStyle(self.nameLabel)
        
        return totalWidth, margin
    end

    f:UpdateLayout()
    return f
end

-----------------------------------------------------------------------
-- UI MANAGEMENT
-----------------------------------------------------------------------
UI.teamBars = {}
UI.masterFrame = nil

function UI:UpdatePositionFromDB()
    if not EMA_Buffs.db then return end
    local p = EMA_Buffs.db.teamBarsPos
    if self.masterFrame then
        self.masterFrame:ClearAllPoints()
        self.masterFrame:SetPoint(p.point, UIParent, p.point, p.x, p.y)
    end
end

function UI:Initialize()
    if not self.masterFrame then
        self.masterFrame = CreateFrame("Frame", "EMABuffsMasterFrame", UIParent, "BackdropTemplate")
        self.masterFrame:SetMovable(true)
        self.masterFrame:EnableMouse(true)
        self.masterFrame:RegisterForDrag("LeftButton")
        self.masterFrame:SetFrameStrata("MEDIUM")
        self.masterFrame:SetSize(200, 40)
        self.masterFrame:SetScript("OnDragStart", function(self)
            if not EMA_Buffs.db or not EMA_Buffs.db.lockBars or IsAltKeyDown() then
                self:StartMoving()
            end
        end)
        self.masterFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            if EMA_Buffs.db then
                local point, _, _, x, y = self:GetPoint()
                EMA_Buffs.db.teamBarsPos = { point = point, x = x, y = y }
            end
        end)
    end
    
    self:UpdatePositionFromDB()
    self:RefreshBars()
end

function UI:RefreshBars()
    if not EMA_Buffs.db or not self.masterFrame then return end
    
    local db = EMA_Buffs.db
    if not db.showBars then
        self.masterFrame:Hide()
        for _, bar in pairs(self.teamBars) do bar:Hide() end
        return
    end

    if db.integrateWithCooldowns then
        self.masterFrame:Hide()
    else
        self.masterFrame:Show()
        self.masterFrame:SetScale(db.barScale)
        self.masterFrame:SetAlpha(db.barAlpha)
        ApplySkin(self.masterFrame, "frame")
    end
    
    local teamList = {}
    for index, characterName in EMAApi.TeamListOrdered() do
        if EMAApi.GetCharacterOnlineStatus(characterName) == true and db.enabledMembers[characterName] ~= false then
            local class, color = EMAApi.GetClass(characterName)
            table.insert(teamList, { name = characterName, position = index, color = color })
        end
    end

    local order = db.barOrder
    if order == "NameAsc" then
        table.sort(teamList, function(a, b) return a.name < b.name end)
    elseif order == "NameDesc" then
        table.sort(teamList, function(a, b) return a.name > b.name end)
    elseif order == "EMAPosition" then
        table.sort(teamList, function(a, b) return a.position < b.position end)
    elseif order == "RoleAsc" then
        local roleWeights = { ["TANK"] = 1, ["HEALER"] = 2, ["DAMAGER"] = 3, ["NONE"] = 4 }
        table.sort(teamList, function(a, b)
            local unitA = Ambiguate(a.name, "none")
            local unitB = Ambiguate(b.name, "none")
            local roleA = UnitGroupRolesAssigned(unitA) or "NONE"
            local roleB = UnitGroupRolesAssigned(unitB) or "NONE"
            if roleA ~= roleB then
                return (roleWeights[roleA] or 99) < (roleWeights[roleB] or 99)
            end
            return a.name < b.name
        end)
    end

    for name, bar in pairs(self.teamBars) do bar:Hide() end

    local currentY = -8
    local barMargin = db.barMargin
    local maxBarWidth = 0
    
    local EMA_Cooldowns = LibStub("AceAddon-3.0"):GetAddon("EMA_Cooldowns", true)

    for _, info in ipairs(teamList) do
        local characterName = info.name
        local color = info.color
        
        if not self.teamBars[characterName] then
            self.teamBars[characterName] = CreateBuffBar(characterName, self.masterFrame)
        end
        local bar = self.teamBars[characterName]
        local buffWidth, buffMargin = bar:UpdateLayout()
        bar:ClearAllPoints()
        
        local cdBar = nil
        if EMA_Cooldowns and EMA_Cooldowns.teamBars then
            cdBar = EMA_Cooldowns.teamBars[characterName]
            if cdBar then
                cdBar.extraWidth = 0
                cdBar.leftExtraWidth = 0
                cdBar:UpdateLayout()
            end
        end

        if db.integrateWithCooldowns and cdBar and cdBar:IsVisible() then
            local extraWidth = (buffWidth > 0) and (buffWidth + buffMargin) or 0
            if db.integratePosition == "Right" then
                cdBar.extraWidth = extraWidth
            else
                cdBar.leftExtraWidth = extraWidth
            end
            cdBar:UpdateLayout()
            bar:SetParent(cdBar)
            if db.integratePosition == "Right" then
                bar:SetPoint("BOTTOMLEFT", cdBar, "BOTTOMLEFT", cdBar:GetWidth() - extraWidth - 4 + buffMargin, 0)
            else
                bar:SetPoint("BOTTOMLEFT", cdBar, "BOTTOMLEFT", 4, 0)
            end
        else
            bar:SetParent(self.masterFrame)
            bar:SetPoint("TOPLEFT", 8, currentY)
            currentY = currentY - bar:GetHeight() - barMargin
        end
        
        bar:Show()
        
        if color then
            bar.nameLabel:SetTextColor(color.r, color.g, color.b)
        end
        
        maxBarWidth = math.max(maxBarWidth, bar:GetWidth())
    end
    
    if not db.integrateWithCooldowns then
        if #teamList > 0 then
            self.masterFrame:SetHeight(math.abs(currentY) - barMargin + 8)
            self.masterFrame:SetWidth(maxBarWidth + 16)
        else
            self.masterFrame:SetHeight(40)
            self.masterFrame:SetWidth(200)
        end
    end
end

function UI:UpdateUI()
    for _, bar in pairs(self.teamBars) do
        if bar:IsShown() then
            bar:UpdateLayout()
        end
    end
end

local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed > 0.2 then
        UI:UpdateUI()
        self.elapsed = 0
    end
end)
