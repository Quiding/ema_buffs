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
        -- Insets set to 0 to make background match icon height perfectly
        f:SetBackdrop({
            bgFile = backgroundFile,
            edgeFile = borderFile,
            tile = false, tileSize = 0, edgeSize = 2,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
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

    -- Move Handle
    f.handle = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.handle:SetSize(10, 10)
    f.handle:SetPoint("TOPRIGHT", f, "TOPLEFT", 0, 0)
    f.handle:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f.handle:SetBackdropColor(0, 0, 0, 1); f.handle:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    f.handle:EnableMouse(true); f.handle:RegisterForDrag("LeftButton")
    f.handle:SetScript("OnDragStart", function() if not EMA_Buffs.db or not EMA_Buffs.db.lockBars then f:StartMoving() end end)
    f.handle:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, relativePoint, x, y = f:GetPoint()
        if point then
            local charKey = Ambiguate(f.characterName, "none"):lower()
            EMA_Buffs.db.individualBarPositions[charKey] = { point = point, relativePoint = relativePoint, x = x, y = y }
        end
    end)

    f.UpdateLayout = function(self)
        if not EMA_Buffs.db then return end
        local db = EMA_Buffs.db
        local charKey = Ambiguate(self.characterName, "none"):lower()
        local pClass, _ = EMAApi.GetClass(self.characterName)
        if not pClass or pClass == self.characterName then _, pClass = UnitClass(Ambiguate(self.characterName, "none")) end
        local classKey = pClass and pClass:upper() or "SHAMAN"
        local tracked = db.trackedBuffs[classKey] or {}
        
        local EMA_Cooldowns = LibStub("AceAddon-3.0"):GetAddon("EMA_Cooldowns", true)
        local integrated = db.integrateWithCooldowns and EMA_Cooldowns and EMA_Cooldowns.db
        
        local size, margin, showNames, layout = db.iconSize, db.iconMargin, db.showNames, db.barLayout or "Horizontal"
        local runningAlpha, missingAlpha = db.runningAlpha, db.missingAlpha

        if integrated then
            size, margin = EMA_Cooldowns.db.iconSize or size, EMA_Cooldowns.db.iconMargin or margin
            showNames, layout = false, EMA_Cooldowns.db.barLayout or "Horizontal"
        end
        local nameHeight = showNames and (db.fontSize + 2) or 0
        
        for _, iconFrame in ipairs(self.icons) do iconFrame:Hide() end

        local activeCount = 0
        for i, buffInfo in ipairs(tracked) do
            activeCount = i
            if not self.icons[i] then
                local b = CreateFrame("Frame", nil, self, "BackdropTemplate")
                b:SetFrameLevel(self:GetFrameLevel() + 2)
                b.icon = b:CreateTexture(nil, "BACKGROUND"); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                b.glow = b:CreateTexture(nil, "OVERLAY", nil, 7); b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); b.glow:SetBlendMode("ADD")
                b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate"); b.cooldown:SetAllPoints(b.icon); b.cooldown:SetDrawEdge(false); b.cooldown:SetFrameLevel(b:GetFrameLevel() + 1)
                b.stackText = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge"); b.stackText:SetPoint("BOTTOMRIGHT", -2, 2)
                self.icons[i] = b
            end
            local b = self.icons[i]
            b:SetSize(size, size); b:ClearAllPoints()
            -- STRICT TOPLEFT anchoring
            if layout == "Horizontal" then b:SetPoint("TOPLEFT", (i-1)*(size + margin), -nameHeight)
            else b:SetPoint("TOPLEFT", 0, -(i-1)*(size + margin) - nameHeight) end
            
            b:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = nil, edgeSize = 0 }); b:SetBackdropColor(0, 0, 0, 0)
            b.icon:ClearAllPoints(); b.icon:SetAllPoints(b); b.glow:ClearAllPoints(); b.glow:SetPoint("TOPLEFT", -4, 4); b.glow:SetPoint("BOTTOMRIGHT", 4, -4)
            b.icon:SetTexture(buffInfo.icon or 134400)
            
            local LBG, activeData = LibStub("LibButtonGlow-1.0", true), EMA_Buffs.activeBuffs[charKey] and EMA_Buffs.activeBuffs[charKey][buffInfo.name]
            if activeData then
                b.glow:Hide(); if LBG then LBG.HideOverlayGlow(b) end
                if activeData.duration > 0 and activeData.expirationTime > 0 then
                    b:SetAlpha(runningAlpha or 0.3); b.icon:SetAlpha(1.0); b.cooldown:SetCooldown(activeData.expirationTime - activeData.duration, activeData.duration); b.cooldown:Show()
                else b:SetAlpha(1.0); b.icon:SetAlpha(1.0); b.cooldown:Hide() end
                if activeData.count and activeData.count > 1 then
                    b.stackText:SetFont(SharedMedia:Fetch("font", db.fontStyle), db.stackFontSize, "OUTLINE"); b.stackText:SetTextColor(db.stackColorR or 1, db.stackColorG or 1, db.stackColorB or 0); b.stackText:SetText(activeData.count); b.stackText:Show()
                else b.stackText:Hide() end
            else
                b:SetAlpha(missingAlpha or 0.2); b.icon:SetAlpha(1.0); b.cooldown:Hide(); b.stackText:Hide()
                if db.glowIfMissing then
                    if db.glowAnimated and LBG then b.glow:Hide(); LBG.ShowOverlayGlow(b, { color = { db.glowColorR or 1, db.glowColorG or 0, db.glowColorB or 0, db.glowColorA or 1 } })
                    else if LBG then LBG.HideOverlayGlow(b) end; b.glow:SetVertexColor(db.glowColorR or 1, db.glowColorG or 0, db.glowColorB or 0, db.glowColorA or 1); b.glow:Show() end
                else b.glow:Hide(); if LBG then LBG.HideOverlayGlow(b) end end
            end
            b:Show()
        end

        ApplyFontStyle(self.nameLabel)
        local nameWidth = (not integrated and showNames) and (self.nameLabel:GetStringWidth() + 4) or 0
        local iconsBoundingSize = (activeCount > 0) and ((size * activeCount) + (margin * math.max(0, activeCount - 1))) or 0
        
        local totalW, totalH = 0, 0
        if layout == "Horizontal" then totalW, totalH = math.max(nameWidth, iconsBoundingSize), size + nameHeight
        else totalW, totalH = math.max(size, nameWidth), iconsBoundingSize + nameHeight end
        self:SetSize(math.max(1, totalW), math.max(1, totalH))

        self.handle:SetShown(db.breakUpBars and not db.lockBars and not integrated)
        self.handle:SetWidth(10); self.handle:SetHeight(totalH); self.handle:ClearAllPoints(); self.handle:SetPoint("TOPRIGHT", self, "TOPLEFT", 0, 0)

        if not db.integrateWithCooldowns then
            if showNames then self.nameLabel:Show(); self.nameLabel:SetJustifyH("LEFT"); self.nameLabel:ClearAllPoints(); self.nameLabel:SetPoint("TOPLEFT", 0, 0)
            else self.nameLabel:Hide() end
            ApplySkin(self, "bar")
        else self.nameLabel:Hide(); self:SetBackdrop(nil) end
        
        self.contentSize, self.activeCount, self.iconSize, self.iconMargin = iconsBoundingSize, activeCount, size, margin
        return iconsBoundingSize, margin, size
    end
    f:UpdateLayout(); return f
end

-----------------------------------------------------------------------
-- UI MANAGEMENT
-----------------------------------------------------------------------
UI.teamBars = {}
UI.masterFrame = nil

function UI:UpdatePositionFromDB()
    if not EMA_Buffs.db then return end
    local p = EMA_Buffs.db.teamBarsPos
    if self.masterFrame then self.masterFrame:ClearAllPoints(); self.masterFrame:SetPoint(p.point, UIParent, p.point, p.x, p.y) end
end

function UI:Initialize()
    if not self.masterFrame then
        self.masterFrame = CreateFrame("Frame", "EMABuffsMasterFrame", UIParent, "BackdropTemplate")
        self.masterFrame:SetMovable(true); self.masterFrame:EnableMouse(true); self.masterFrame:SetFrameStrata("MEDIUM"); self.masterFrame:SetSize(200, 40)
        self.masterFrame.handle = CreateFrame("Frame", nil, self.masterFrame, "BackdropTemplate")
        self.masterFrame.handle:SetSize(10, 40); self.masterFrame.handle:SetPoint("TOPRIGHT", self.masterFrame, "TOPLEFT", 0, 0)
        self.masterFrame.handle:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        self.masterFrame.handle:SetBackdropColor(0, 0, 0, 1); self.masterFrame.handle:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
        self.masterFrame.handle:EnableMouse(true); self.masterFrame.handle:RegisterForDrag("LeftButton")
        self.masterFrame.handle:SetScript("OnDragStart", function() if not EMA_Buffs.db or not EMA_Buffs.db.lockBars then self.masterFrame:StartMoving() end end)
        self.masterFrame.handle:SetScript("OnDragStop", function()
            self.masterFrame:StopMovingOrSizing()
            if EMA_Buffs.db then local point, _, relativePoint, x, y = self.masterFrame:GetPoint(); EMA_Buffs.db.teamBarsPos = { point = point, relativePoint = relativePoint, x = x, y = y } end
        end)
    end
    self:UpdatePositionFromDB(); self:RefreshBars()
end

function UI:RefreshBars()
    if not EMA_Buffs.db or not self.masterFrame then return end
    local db, EMA_Cooldowns = EMA_Buffs.db, LibStub("AceAddon-3.0"):GetAddon("EMA_Cooldowns", true)

    -- CLEAR STATE
    if EMA_Cooldowns and EMA_Cooldowns.teamBars then
        for _, cdBar in pairs(EMA_Cooldowns.teamBars) do
            cdBar.extraWidth, cdBar.leftExtraWidth, cdBar.extraHeight, cdBar.topExtraHeight, cdBar.topExtraWidth, cdBar.bottomExtraWidth = 0,0,0,0,0,0
        end
    end

    if not db.showBars then
        self.masterFrame:Hide(); for _, bar in pairs(self.teamBars) do bar:Hide() end
        if EMA_Cooldowns and EMA_Cooldowns.teamBars then for _, cdBar in pairs(EMA_Cooldowns.teamBars) do cdBar:UpdateLayout() end end
        return
    end

    if db.integrateWithCooldowns or db.breakUpBars then self.masterFrame:Hide()
    else self.masterFrame:Show(); self.masterFrame:SetScale(db.barScale); self.masterFrame:SetAlpha(db.barAlpha); ApplySkin(self.masterFrame, "frame"); self.masterFrame.handle:SetShown(not db.lockBars) end
    
    local teamList = {}
    for index, characterName in EMAApi.TeamListOrdered() do
        local isOnline = EMAApi.GetCharacterOnlineStatus(characterName)
        if (isOnline == true or characterName == self.characterName) and db.enabledMembers[characterName] ~= false then
            local class, color = EMAApi.GetClass(characterName); table.insert(teamList, { name = characterName, position = index, color = color })
        end
    end

    local order = db.barOrder
    if order == "NameAsc" then table.sort(teamList, function(a, b) return a.name < b.name end)
    elseif order == "NameDesc" then table.sort(teamList, function(a, b) return a.name > b.name end)
    elseif order == "EMAPosition" then table.sort(teamList, function(a, b) return a.position < b.position end)
    elseif order == "RoleAsc" then
        local roleWeights = { ["TANK"] = 1, ["HEALER"] = 2, ["DAMAGER"] = 3, ["NONE"] = 4 }
        table.sort(teamList, function(a, b)
            local unitA, unitB = Ambiguate(a.name, "none"), Ambiguate(b.name, "none")
            local roleA, roleB = UnitGroupRolesAssigned(unitA) or "NONE", UnitGroupRolesAssigned(unitB) or "NONE"
            if roleA ~= roleB then return (roleWeights[roleA] or 99) < (roleWeights[roleB] or 99) end
            return a.name < b.name
        end)
    end

    for name, bar in pairs(self.teamBars) do bar:Hide() end
    local curX, curY, barMargin = 0, 0, db.barMargin
    local maxTotalWidth, maxTotalHeight = 0, 0
    
    for _, info in ipairs(teamList) do
        local characterName, color = info.name, info.color
        if not self.teamBars[characterName] then self.teamBars[characterName] = CreateBuffBar(characterName, self.masterFrame) end
        local bar = self.teamBars[characterName]
        bar:UpdateLayout()
        
        local cdBar = (EMA_Cooldowns and EMA_Cooldowns.teamBars) and EMA_Cooldowns.teamBars[characterName] or nil

        if db.integrateWithCooldowns and cdBar and cdBar:IsVisible() then
            local cdDB = EMA_Cooldowns.db
            local cdSize, cdIconMargin = cdDB.iconSize or 30, cdDB.iconMargin or 0
            
            -- SOURCE OF TRUTH: Force re-layout then read confirmed dimensions
            cdBar:UpdateLayout() 
            local parentCount = cdBar.activeCount or 0
            local parentContentW = cdBar.contentWidth or 0
            local parentContentH = cdBar.contentHeight or 0
            local parentLayout = cdDB.barLayout or "Horizontal"
            local parentNameH = (cdDB.showNames) and (cdDB.fontSize + 2) or 0
            local gap = cdIconMargin -- Unified Spacing
            
            local buffStackSize = bar.contentSize or 0
            local buffIconSize = bar.iconSize or 30
            -- If integrated row matches parent orientation, its stack size is its dimension
            local bW, bH = buffIconSize, buffIconSize
            if parentLayout == "Horizontal" then bW = buffStackSize else bH = buffStackSize end

            if db.integratePosition == "Right" then cdBar.extraWidth = (buffStackSize > 0) and (bW + gap) or 0
            elseif db.integratePosition == "Left" then cdBar.leftExtraWidth = (buffStackSize > 0) and (bW + gap) or 0
            elseif db.integratePosition == "Bottom" then cdBar.extraHeight, cdBar.bottomExtraWidth = (buffStackSize > 0) and (bH + gap) or 0, bW
            elseif db.integratePosition == "Top" then cdBar.topExtraHeight, cdBar.topExtraWidth = (buffStackSize > 0) and (bH + gap) or 0, bW end
            
            cdBar:UpdateLayout() 
            bar:SetParent(cdBar); bar:SetMovable(false); bar:SetScale(1.0); bar:SetAlpha(1.0); bar:ClearAllPoints()
            local leftOff, topOff = cdBar.leftExtraWidth or 0, cdBar.topExtraHeight or 0
            
            -- PIXEL-PERFECT TOPLEFT INTEGRATION
            if db.integratePosition == "Right" then
                local xOff = (parentLayout == "Horizontal") and (parentCount * (cdSize + gap)) or (cdSize + gap)
                bar:SetPoint("TOPLEFT", cdBar, "TOPLEFT", xOff + leftOff, -parentNameH - topOff)
            elseif db.integratePosition == "Left" then
                bar:SetPoint("TOPLEFT", cdBar, "TOPLEFT", 0, -parentNameH - topOff)
            elseif db.integratePosition == "Bottom" then
                local yOff = topOff + parentContentH + parentNameH + gap
                bar:SetPoint("TOPLEFT", cdBar, "TOPLEFT", leftOff, -yOff)
            elseif db.integratePosition == "Top" then
                bar:SetPoint("TOPLEFT", cdBar, "TOPLEFT", leftOff, -parentNameH)
            end
        elseif db.breakUpBars then
            local pos = db.individualBarPositions[Ambiguate(characterName, "none"):lower()]
            bar:SetParent(UIParent); bar:SetMovable(true); bar:SetScale(db.barScale); bar:SetAlpha(db.barAlpha); bar:SetFrameStrata("MEDIUM"); bar:ClearAllPoints()
            if pos then bar:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y) else bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
        else
            bar:SetParent(self.masterFrame); bar:SetMovable(false); bar:SetScale(1.0); bar:SetAlpha(1.0); bar:ClearAllPoints(); bar:SetPoint("TOPLEFT", curX, curY)
        end
        
        bar:UpdateLayout(); bar:Show()
        if not db.integrateWithCooldowns and not db.breakUpBars then
            if db.barLayout == "Vertical" then curX, maxTotalHeight = curX + bar:GetWidth() + barMargin, math.max(maxTotalHeight, bar:GetHeight())
            else curY, maxTotalWidth = curY - bar:GetHeight() - barMargin, math.max(maxTotalWidth, bar:GetWidth()) end
        end
        if color then bar.nameLabel:SetTextColor(color.r, color.g, color.b) end
    end
    
    if not db.integrateWithCooldowns and not db.breakUpBars then
        if #teamList > 0 then
            if db.barLayout == "Vertical" then self.masterFrame:SetSize(curX - barMargin, maxTotalHeight)
            else self.masterFrame:SetSize(maxTotalWidth, math.abs(curY) - barMargin) end
            self.masterFrame.handle:SetHeight(self.masterFrame:GetHeight())
        else self.masterFrame:SetSize(200, 40) end
    end
end

function UI:UpdateUI() for _, bar in pairs(self.teamBars) do if bar:IsShown() then bar:UpdateLayout() end end end

local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed > 0.2 then UI:UpdateUI(); self.elapsed = 0 end
end)
