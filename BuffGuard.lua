local addonName = ...

-- Always-visible invisible driver frame so OnUpdate continues running while the visual HUD is hidden
local driver = CreateFrame("Frame", "BuffGuardDriver", UIParent)
local frame = CreateFrame("Frame", "BuffGuardFrame", UIParent)
frame:Hide()

-- C++ state-driven secure parent: automatically hides click overlays in combat so they never block camera turning
local secureHolder = CreateFrame("Frame", "BuffGuardSecureHolder", UIParent, "SecureHandlerStateTemplate")
secureHolder:SetAllPoints(UIParent)
if RegisterStateDriver then
    pcall(RegisterStateDriver, secureHolder, "visibility", "[combat] hide; show")
end

local db
local inCombat = false
local unlocked = false
local previewUntil = 0
local pollElapsed = 0
local renderElapsed = 0
local pendingSecureSync = false
local activeBadges = {}
local currentSpec = "none" -- "holy" | "protection" | "retribution" | "none"
local talentPoints = { 0, 0, 0 } -- { Holy, Protection, Retribution }
local Render

---------------------------------------------------------------------------
-- Localization (esES / esMX & enUS / enGB)
---------------------------------------------------------------------------

local clientLocale = (GetLocale and GetLocale()) or "enUS"
local defaultLang = (clientLocale == "esES" or clientLocale == "esMX") and "es" or "en"

local L_TABLE = {
    es = {
        LABEL_RF = "FURIA",
        LABEL_AURA = "AURA",
        LABEL_BLESSING = "BENDICIÓN",
        MOVER_HINT = "|cffffd36aArrastra para mover|r |cffaaaaaa(Clic derecho para bloquear)|r",
        MSG_COMBAT_LOCK = "Sal de combate un momento para mover los iconos.",
        MSG_MOVE_ON = "Modo mover |cff00ff00ACTIVO|r. Arrastra los iconos y haz |cffffd36aclic derecho|r (o escribe /bguard) para bloquear.",
        MSG_MOVE_OFF = "Posición |cffffd36abloqueada|r. Escribe |cffffd36a/bguard|r si quieres volver a moverlo.",
        MSG_SCALE_SET = "Tamaño ajustado a |cffffd36a%s|r.",
        MSG_SCALE_USAGE = "Usa: |cffffd36a/bguard scale 0.85|r (entre 0.4 y 2.0)",
        MSG_LABELS_ON = "Textos inferiores |cff00ff00activados|r.",
        MSG_LABELS_OFF = "Textos inferiores |cffff5555ocultos|r.",
        MSG_COMBAT_ONLY_ON = "Modo: Avisar |cffffd36asolo en combate|r.",
        MSG_COMBAT_ONLY_OFF = "Modo: Avisar |cff00ff00siempre|r (combate y fuera de combate).",
        MSG_RF_AUTO = "Aviso de Furia justa: |cff00ff00AUTOMÁTICO|r (solo avisa en talentos de |cffffd36aProtección|r).",
        MSG_RF_ON = "Aviso de Furia justa: |cff00ff00SIEMPRE ACTIVO|r (forzado en cualquier rama).",
        MSG_RF_OFF = "Aviso de Furia justa: |cffff5555DESACTIVADO|r.",
        MSG_AURA_ON = "Aviso de Aura |cff00ff00activado|r.",
        MSG_AURA_OFF = "Aviso de Aura |cffff5555desactivado|r.",
        MSG_BLESS_ON = "Aviso de Bendición |cff00ff00activado|r.",
        MSG_BLESS_OFF = "Aviso de Bendición |cffff5555desactivado|r.",
        MSG_RESET = "Posición, tamaño y preferencias restablecidos.",
        MSG_LANG_SET = "Idioma cambiado a |cffffd36aEspañol (esES)|r.",
        MSG_WELCOME = "Activado para las 3 ramas de Paladín. Escribe |cffffd36a/bguard|r para mover los iconos o haz clic en ellos para bufarte.",
        MSG_STATUS = "Rama detectada: |cffffd36a%s|r (%d/%d/%d) | Furia justa: |cffffd36a%s|r (%s)",
        MSG_HELP = "Comandos: |cffffd36a/bguard|r (mover) | |cffffd36a/bguard status|r | |cffffd36a/bguard rf [auto|on|off]|r | |cffffd36a/bguard aura|r | |cffffd36a/bguard bendicion|r | |cffffd36a/bguard scale 0.85|r | |cffffd36a/bguard texto|r | |cffffd36a/bguard combate|r | |cffffd36a/bguard lang [es|en]|r | |cffffd36a/bguard reset|r",
        SPEC_HOLY = "Sagrado",
        SPEC_PROTECTION = "Protección",
        SPEC_RETRIBUTION = "Reprensión",
        SPEC_NONE = "Sin talentos (< nivel 10)",
        STATE_ACTIVE = "vigilando",
        STATE_INACTIVE = "no requerida en esta rama",
    },
    en = {
        LABEL_RF = "FURY",
        LABEL_AURA = "AURA",
        LABEL_BLESSING = "BLESSING",
        MOVER_HINT = "|cffffd36aDrag to move|r |cffaaaaaa(Right-click to lock)|r",
        MSG_COMBAT_LOCK = "Leave combat for a moment to move the icons.",
        MSG_MOVE_ON = "Move mode |cff00ff00ACTIVE|r. Drag the icons and |cffffd36aright-click|r (or type /bguard) to lock.",
        MSG_MOVE_OFF = "Position |cffffd36alocked|r. Type |cffffd36a/bguard|r if you want to move it again.",
        MSG_SCALE_SET = "Scale set to |cffffd36a%s|r.",
        MSG_SCALE_USAGE = "Usage: |cffffd36a/bguard scale 0.85|r (between 0.4 and 2.0)",
        MSG_LABELS_ON = "Bottom labels |cff00ff00enabled|r.",
        MSG_LABELS_OFF = "Bottom labels |cffff5555hidden|r.",
        MSG_COMBAT_ONLY_ON = "Mode: Alert |cffffd36ain combat only|r.",
        MSG_COMBAT_ONLY_OFF = "Mode: Alert |cff00ff00always|r (in and out of combat).",
        MSG_RF_AUTO = "Righteous Fury alert: |cff00ff00AUTO|r (only alerts when in |cffffd36aProtection|r talents).",
        MSG_RF_ON = "Righteous Fury alert: |cff00ff00ALWAYS ON|r (forced in all specs).",
        MSG_RF_OFF = "Righteous Fury alert: |cffff5555DISABLED|r.",
        MSG_AURA_ON = "Aura alert |cff00ff00enabled|r.",
        MSG_AURA_OFF = "Aura alert |cffff5555disabled|r.",
        MSG_BLESS_ON = "Blessing alert |cff00ff00enabled|r.",
        MSG_BLESS_OFF = "Blessing alert |cffff5555disabled|r.",
        MSG_RESET = "Position, scale, and preferences reset.",
        MSG_LANG_SET = "Language set to |cffffd36aEnglish (enUS)|r.",
        MSG_WELCOME = "Active for all 3 Paladin specs. Type |cffffd36a/bguard|r to move the icons or click them to buff up.",
        MSG_STATUS = "Detected spec: |cffffd36a%s|r (%d/%d/%d) | Righteous Fury: |cffffd36a%s|r (%s)",
        MSG_HELP = "Commands: |cffffd36a/bguard|r (move) | |cffffd36a/bguard status|r | |cffffd36a/bguard rf [auto|on|off]|r | |cffffd36a/bguard aura|r | |cffffd36a/bguard blessing|r | |cffffd36a/bguard scale 0.85|r | |cffffd36a/bguard text|r | |cffffd36a/bguard combat|r | |cffffd36a/bguard lang [es|en]|r | |cffffd36a/bguard reset|r",
        SPEC_HOLY = "Holy",
        SPEC_PROTECTION = "Protection",
        SPEC_RETRIBUTION = "Retribution",
        SPEC_NONE = "No talents (< level 10)",
        STATE_ACTIVE = "watching",
        STATE_INACTIVE = "not required in this spec",
    },
}

local function GetLang()
    if db and (db.lang == "es" or db.lang == "en") then
        return db.lang
    end
    return defaultLang
end

local function L(key)
    local langTable = L_TABLE[GetLang()] or L_TABLE.es
    return langTable[key] or L_TABLE.es[key] or key
end

---------------------------------------------------------------------------
-- Spell IDs & Localized Fallbacks (WoW Forever 16001)
---------------------------------------------------------------------------

local RF_SPELL_IDS = { 25780 }
local AURA_SPELL_IDS = {
    465,   -- Devotion Aura
    7294,  -- Retribution Aura
    19746, -- Concentration Aura
    19876, -- Shadow Resistance Aura
    19888, -- Frost Resistance Aura
    19891, -- Fire Resistance Aura
    20218, -- Sanctity Aura
}
local BLESSING_SPELL_IDS = {
    19740, 19834, 19835, 19836, 19837, 19838, 25291, -- Might
    19742, 19850, 19852, 19853, 19854, 25290,        -- Wisdom
    20217,                                           -- Kings
    20911, 20912, 20913, 20914,                      -- Sanctuary
    19977, 19978, 19979,                             -- Light
    1038,                                            -- Salvation
    25782, 25916,                                    -- Greater Might
    25894, 25918,                                    -- Greater Wisdom
    25898,                                           -- Greater Kings
    25899,                                           -- Greater Sanctuary
    25890,                                           -- Greater Light
    25895,                                           -- Greater Salvation
}

-- Fallback localized names (esES / esMX / enUS)
local rfNames = {
    ["Furia recta"] = true,
    ["Furia justa"] = true,
    ["Righteous Fury"] = true,
}
local auraNames = {
    ["Aura de devoción"] = true,
    ["Aura de retribución"] = true,
    ["Aura de represalia"] = true,
    ["Aura de castigo"] = true,
    ["Aura de concentración"] = true,
    ["Aura de santidad"] = true,
    ["Aura de resistencia a las Sombras"] = true,
    ["Aura de resistencia a la Escarcha"] = true,
    ["Aura de resistencia al Fuego"] = true,
    ["Devotion Aura"] = true,
    ["Retribution Aura"] = true,
    ["Concentration Aura"] = true,
    ["Sanctity Aura"] = true,
    ["Shadow Resistance Aura"] = true,
    ["Frost Resistance Aura"] = true,
    ["Fire Resistance Aura"] = true,
}
local blessingNames = {
    ["Bendición del poderío"] = true,
    ["Bendición de poderío"] = true,
    ["Bendición de Sabiduría"] = true,
    ["Bendición de sabiduría"] = true,
    ["Bendición de los Reyes"] = true,
    ["Bendición de reyes"] = true,
    ["Bendición de salvaguardia"] = true,
    ["Bendición de santuario"] = true,
    ["Bendición de Luz"] = true,
    ["Bendición de luz"] = true,
    ["Bendición de salvación"] = true,
    ["Bendición de poderío superior"] = true,
    ["Bendición de sabiduría superior"] = true,
    ["Bendición de los reyes superior"] = true,
    ["Bendición de santuario superior"] = true,
    ["Bendición de luz superior"] = true,
    ["Bendición de salvación superior"] = true,
    ["Blessing of Might"] = true,
    ["Blessing of Wisdom"] = true,
    ["Blessing of Kings"] = true,
    ["Blessing of Sanctuary"] = true,
    ["Blessing of Light"] = true,
    ["Blessing of Salvation"] = true,
    ["Greater Blessing of Might"] = true,
    ["Greater Blessing of Wisdom"] = true,
    ["Greater Blessing of Kings"] = true,
    ["Greater Blessing of Sanctuary"] = true,
    ["Greater Blessing of Light"] = true,
    ["Greater Blessing of Salvation"] = true,
}

local DEFAULT_ICONS = {
    rf = "Interface\\Icons\\Spell_Holy_SealOfFury",
    aura = "Interface\\Icons\\Spell_Holy_AuraOfLight",
    blessing = "Interface\\Icons\\Spell_Holy_FistOfJustice",
}

-- Resolved spell names by type for smart per-spec click-casting at max rank
local resolvedSpells = {
    rf = (defaultLang == "es") and "Furia justa" or "Righteous Fury",
    devotionAura = (defaultLang == "es") and "Aura de devoción" or "Devotion Aura",
    retributionAura = (defaultLang == "es") and "Aura de represalia" or "Retribution Aura",
    concentrationAura = (defaultLang == "es") and "Aura de concentración" or "Concentration Aura",
    sanctityAura = (defaultLang == "es") and "Aura de santidad" or "Sanctity Aura",
    blessingMight = (defaultLang == "es") and "Bendición del poderío" or "Blessing of Might",
    blessingWisdom = (defaultLang == "es") and "Bendición de Sabiduría" or "Blessing of Wisdom",
    blessingKings = (defaultLang == "es") and "Bendición de los Reyes" or "Blessing of Kings",
    blessingSanctuary = (defaultLang == "es") and "Bendición de salvaguardia" or "Blessing of Sanctuary",
}

-- Tracked runtime state (persists across restricted combat scans)
local tracked = {
    rf = { active = false, expirationTime = 0, duration = 1800, icon = DEFAULT_ICONS.rf, instanceID = nil },
    aura = { active = false, expirationTime = 0, duration = 0, icon = DEFAULT_ICONS.aura, instanceID = nil },
    blessing = { active = false, expirationTime = 0, duration = 300, icon = DEFAULT_ICONS.blessing, instanceID = nil },
}

local function IsReadable(value)
    return not (issecretvalue and issecretvalue(value))
end

local function IsFiniteNumber(value)
    return IsReadable(value) and type(value) == "number"
        and value == value and value > -math.huge and value < math.huge
end

local function IsReadableString(value)
    return IsReadable(value) and type(value) == "string"
end

local function InCombat()
    return (InCombatLockdown and InCombatLockdown()) or inCombat
end

local function Message(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd36aBuffGuard:|r " .. text)
end

local function HasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name)
end

local function IsPlayerSpellKnown(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        if ok and IsReadable(known) and known then return true end
    end
    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, spellID)
        if ok and IsReadable(known) and known then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- WoW Forever (1.60.1 / 16001) Talent Spec Detection (3 Paladin Branches)
-- Columns left-to-right: 1 = Holy, 2 = Protection, 3 = Retribution
---------------------------------------------------------------------------

local function GetForeverTreePoints()
    local CT, T = C_ClassTalents, C_Traits
    if CT and CT.GetActiveConfigID and T and T.GetConfigInfo and T.GetGroupDisplayInfoByTreeID and T.GetGroupCurrencyInfo then
        local ok, config = pcall(CT.GetActiveConfigID)
        if ok and IsFiniteNumber(config) then
            local ok2, info = pcall(T.GetConfigInfo, config)
            local tree = ok2 and type(info) == "table" and type(info.treeIDs) == "table" and info.treeIDs[1]
            if IsFiniteNumber(tree) then
                local ok3, shown = pcall(T.GetGroupDisplayInfoByTreeID, tree)
                if ok3 and type(shown) == "table" and shown[1] then
                    local ids = {}
                    for i, d in ipairs(shown) do ids[i] = d.groupID end
                    local ok4, groups = pcall(T.GetGroupCurrencyInfo, config, ids)
                    local spent = {}
                    if ok4 and type(groups) == "table" then
                        for _, g in ipairs(groups) do
                            local c = type(g) == "table" and type(g.currencyInfos) == "table" and g.currencyInfos[1]
                            if type(c) == "table" and g.traitNodeGroupID ~= nil and IsFiniteNumber(c.spent) then
                                spent[g.traitNodeGroupID] = c.spent
                            end
                        end
                    end
                    local p1 = (shown[1] and spent[shown[1].groupID]) or 0
                    local p2 = (shown[2] and spent[shown[2].groupID]) or 0
                    local p3 = (shown[3] and spent[shown[3].groupID]) or 0
                    return p1, p2, p3, true
                end
            end
        end
    end

    -- Fallback 2: C_SpecializationInfo.GetSpecializationInfo(1..3)
    local S = C_SpecializationInfo
    if S and S.GetSpecializationInfo then
        local pts = { 0, 0, 0 }
        local anyOk = false
        for i = 1, 3 do
            local ok, _, _, _, _, _, _, points = pcall(S.GetSpecializationInfo, i)
            if ok and IsFiniteNumber(points) then
                pts[i] = points
                anyOk = true
            end
        end
        if anyOk then
            return pts[1], pts[2], pts[3], true
        end
    end

    -- Fallback 3: Classic GetTalentTabInfo(1..3)
    if GetTalentTabInfo then
        local pts = { 0, 0, 0 }
        local anyOk = false
        for i = 1, 3 do
            local ok, _, _, pointsSpent = pcall(GetTalentTabInfo, i)
            if ok and IsFiniteNumber(pointsSpent) then
                pts[i] = pointsSpent
                anyOk = true
            end
        end
        if anyOk then
            return pts[1], pts[2], pts[3], true
        end
    end

    return 0, 0, 0, false
end

local function DetectPaladinSpec()
    local p1, p2, p3, found = GetForeverTreePoints()
    talentPoints[1], talentPoints[2], talentPoints[3] = p1, p2, p3

    if found and (p1 > 0 or p2 > 0 or p3 > 0) then
        if p2 > 0 and p2 >= p1 and p2 >= p3 then
            currentSpec = "protection"
        elseif p1 > 0 and p1 >= p2 and p1 >= p3 then
            currentSpec = "holy"
        else
            currentSpec = "retribution"
        end
        return currentSpec
    end

    -- Fallback: Primary spec selection on clients where 0 points are spent but a tab is selected
    local S = C_SpecializationInfo
    if S and S.GetSpecialization then
        local ok, idx = pcall(S.GetSpecialization)
        if ok and IsFiniteNumber(idx) then
            if idx == 1 then currentSpec = "holy"; return currentSpec end
            if idx == 2 then currentSpec = "protection"; return currentSpec end
            if idx == 3 then currentSpec = "retribution"; return currentSpec end
        end
    end

    currentSpec = "none"
    return currentSpec
end

-- Determines if Righteous Fury should be monitored right now
local function ShouldTrackRF()
    if not db then return false end
    local mode = db.rfMode or "auto"
    if mode == "off" then
        return false
    elseif mode == "on" then
        return true
    else
        -- "auto": ONLY alert when in Protection talents!
        return currentSpec == "protection"
    end
end

-- Returns smart primary & secondary spells for Aura and Blessing based on active talent tree
local function GetSpecDefaultSpells()
    local auraPrimary = resolvedSpells.retributionAura
    local auraSecondary = resolvedSpells.devotionAura
    local blessPrimary = resolvedSpells.blessingMight
    local blessSecondary = resolvedSpells.blessingWisdom

    if currentSpec == "protection" then
        auraPrimary = resolvedSpells.devotionAura
        auraSecondary = resolvedSpells.retributionAura
        if IsPlayerSpellKnown(20911) then
            blessPrimary = resolvedSpells.blessingSanctuary
            blessSecondary = resolvedSpells.blessingMight
        else
            blessPrimary = resolvedSpells.blessingMight
            blessSecondary = resolvedSpells.blessingWisdom
        end
    elseif currentSpec == "holy" then
        if IsPlayerSpellKnown(19746) then
            auraPrimary = resolvedSpells.concentrationAura
            auraSecondary = resolvedSpells.devotionAura
        else
            auraPrimary = resolvedSpells.devotionAura
            auraSecondary = resolvedSpells.retributionAura
        end
        blessPrimary = resolvedSpells.blessingWisdom
        if IsPlayerSpellKnown(20217) then
            blessSecondary = resolvedSpells.blessingKings
        else
            blessSecondary = resolvedSpells.blessingMight
        end
    else
        -- Retribution or pre-10 leveling
        if IsPlayerSpellKnown(20218) then
            auraPrimary = resolvedSpells.sanctityAura
            auraSecondary = resolvedSpells.retributionAura
        else
            auraPrimary = resolvedSpells.retributionAura
            auraSecondary = resolvedSpells.devotionAura
        end
        blessPrimary = resolvedSpells.blessingMight
        blessSecondary = resolvedSpells.blessingWisdom
    end

    return auraPrimary, auraSecondary, blessPrimary, blessSecondary
end

local function BuildSpellNames()
    if not (C_Spell and C_Spell.GetSpellName) then return end
    for _, id in ipairs(RF_SPELL_IDS) do
        local name = C_Spell.GetSpellName(id)
        if IsReadableString(name) and name ~= "" then
            rfNames[name] = true
            resolvedSpells.rf = name
        end
    end
    for _, id in ipairs(AURA_SPELL_IDS) do
        local name = C_Spell.GetSpellName(id)
        if IsReadableString(name) and name ~= "" then
            auraNames[name] = true
            if id == 465 then resolvedSpells.devotionAura = name end
            if id == 7294 then resolvedSpells.retributionAura = name end
            if id == 19746 then resolvedSpells.concentrationAura = name end
            if id == 20218 then resolvedSpells.sanctityAura = name end
        end
    end
    for _, id in ipairs(BLESSING_SPELL_IDS) do
        local name = C_Spell.GetSpellName(id)
        if IsReadableString(name) and name ~= "" then
            blessingNames[name] = true
            if id == 19740 then resolvedSpells.blessingMight = name end
            if id == 19742 then resolvedSpells.blessingWisdom = name end
            if id == 20217 then resolvedSpells.blessingKings = name end
            if id == 20911 then resolvedSpells.blessingSanctuary = name end
        end
    end
end

local function IsBlessingName(name)
    if not IsReadableString(name) then return false end
    if blessingNames[name] then return true end
    if name:find("^Bendici\195\179n ") or name:find("^Blessing of ") or name:find("^Greater Blessing of ") then
        -- Exclude Blessing of Protection / Freedom / Sacrifice (short utility cooldowns)
        if not name:find("protecci") and not name:find("libertad")
            and not name:find("Protection") and not name:find("Freedom")
            and not name:find("Sacrifice") and not name:find("sacrificio") then
            blessingNames[name] = true
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Create UI Container & Mover Backdrop
---------------------------------------------------------------------------

local ICON_SIZE = 42
local ICON_GAP = 12

frame:SetSize(ICON_SIZE * 3 + ICON_GAP * 2 + 16, ICON_SIZE + 28)
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")

local moverBg = frame:CreateTexture(nil, "BACKGROUND")
moverBg:SetAllPoints()
moverBg:SetColorTexture(0.05, 0.06, 0.08, 0.78)
moverBg:Hide()

local moverText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
moverText:SetPoint("BOTTOM", frame, "TOP", 0, 4)
moverText:SetText(L("MOVER_HINT"))
moverText:Hide()

local function CreateBadge(key, labelKey, defaultIcon)
    local badge = CreateFrame("Frame", nil, frame)
    badge:SetSize(ICON_SIZE, ICON_SIZE)
    badge.key = key
    badge.labelKey = labelKey
    badge.offsetX = 0
    badge.offsetY = 4

    local bg = badge:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.03, 0.03, 0.04, 0.94)
    badge.bg = bg

    local icon = badge:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetTexture(defaultIcon)
    badge.icon = icon

    if HasAtlas("UI-HUD-CoolDownManager-Mask") and badge.CreateMaskTexture then
        local mask = badge:CreateMaskTexture()
        mask:SetAllPoints(icon)
        mask:SetAtlas("UI-HUD-CoolDownManager-Mask")
        icon:AddMaskTexture(mask)
    end

    local overlay = CreateFrame("Frame", nil, badge)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(badge:GetFrameLevel() + 5)

    local border = overlay:CreateTexture(nil, "OVERLAY")
    local outsetX = math.floor(8 * ICON_SIZE / 52 + 0.5)
    local outsetY = math.floor(7 * ICON_SIZE / 52 + 0.5)
    if HasAtlas("UI-HUD-CoolDownManager-IconOverlay") then
        border:SetAtlas("UI-HUD-CoolDownManager-IconOverlay")
        border:SetPoint("TOPLEFT", icon, "TOPLEFT", -outsetX, outsetY)
        border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", outsetX, -outsetY)
    else
        border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        border:SetPoint("TOPLEFT", icon, "TOPLEFT", -8, 8)
        border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 8, -8)
    end
    badge.border = border

    local glow = overlay:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetPoint("TOPLEFT", icon, "TOPLEFT", -16, 16)
    glow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 16, -16)
    glow:SetVertexColor(1, 0.72, 0.2)
    badge.glow = glow

    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.25)
    fade:SetToAlpha(0.9)
    fade:SetDuration(0.6)
    fade:SetSmoothing("IN_OUT")
    badge.pulse = pulse

    local bounce = badge:CreateAnimationGroup()
    bounce:SetLooping("BOUNCE")
    local lift = bounce:CreateAnimation("Translation")
    lift:SetOffset(0, 5)
    lift:SetDuration(0.32)
    lift:SetSmoothing("IN_OUT")
    badge.bounce = bounce

    -- Small top-right corner indicator ("!") so icon art stays clean
    local badgeMark = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
    badgeMark:SetPoint("TOPRIGHT", badge, "TOPRIGHT", -2, -2)
    badgeMark:SetTextColor(1, 0.35, 0.2)
    badgeMark:SetText("!")
    badge.badgeMark = badgeMark

    -- Center timer for expiring blessings
    local timer = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
    timer:SetPoint("CENTER", badge, "CENTER", 0, 0)
    timer:SetText("")
    badge.timer = timer

    -- Minimalist label underneath
    local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOP", badge, "BOTTOM", 0, -4)
    label:SetText(L(labelKey))
    label:SetTextColor(1, 0.85, 0.45)
    label:SetShadowOffset(1, -1)
    badge.label = label

    -- Secure Action Button overlay parented to secureHolder and anchored to UIParent (never to badge/frame)
    local clickBtn = CreateFrame("Button", "BuffGuardBtn_" .. key, secureHolder, "SecureActionButtonTemplate")
    clickBtn:SetSize(ICON_SIZE, ICON_SIZE)
    clickBtn:SetFrameStrata("MEDIUM")
    clickBtn:SetFrameLevel(badge:GetFrameLevel() + 10)
    clickBtn:RegisterForClicks("AnyUp", "AnyDown")
    clickBtn:SetAttribute("type", "macro")
    clickBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    clickBtn:Hide()
    badge.clickBtn = clickBtn

    badge:Hide()
    return badge
end

local badges = {
    rf = CreateBadge("rf", "LABEL_RF", DEFAULT_ICONS.rf),
    aura = CreateBadge("aura", "LABEL_AURA", DEFAULT_ICONS.aura),
    blessing = CreateBadge("blessing", "LABEL_BLESSING", DEFAULT_ICONS.blessing),
}
local allBadges = { badges.rf, badges.aura, badges.blessing }

local function RefreshBadgeLabels()
    moverText:SetText(L("MOVER_HINT"))
    for _, b in ipairs(allBadges) do
        if b.label and b.labelKey then
            b.label:SetText(L(b.labelKey))
        end
    end
end

local function UpdateSecureButton(btn, macro1, macro2, scale, targetX, targetY, shouldShow)
    if btn.lastMacro1 ~= macro1 then
        btn:SetAttribute("*macrotext1", macro1)
        btn.lastMacro1 = macro1
    end
    if btn.lastMacro2 ~= macro2 then
        btn:SetAttribute("*macrotext2", macro2)
        btn.lastMacro2 = macro2
    end
    if btn.lastScale ~= scale then
        btn:SetScale(scale)
        btn.lastScale = scale
    end
    if btn.lastX ~= targetX or btn.lastY ~= targetY then
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", UIParent, "CENTER", targetX, targetY)
        btn.lastX = targetX
        btn.lastY = targetY
    end
    if btn.lastShown ~= shouldShow then
        btn:SetShown(shouldShow)
        btn.lastShown = shouldShow
    end
end

-- Updates macro text and positions on the SecureActionButtonTemplate overlays (only outside combat)
local function SyncSecureButtons()
    if InCombatLockdown and InCombatLockdown() then
        pendingSecureSync = true
        return
    end
    pendingSecureSync = false

    local scale = (db and db.scale) or 0.85
    local baseX = (db and db.x) or 0
    local baseY = (db and db.y) or 140
    local frameVisible = frame:IsShown() and not unlocked

    local defAura1, defAura2, defBless1, defBless2 = GetSpecDefaultSpells()

    -- 1. Righteous Fury macro (casts max rank automatically when rank is omitted)
    local rfSpell = (db and db.lastRFName) or resolvedSpells.rf
    local rfMacro = "/cast " .. rfSpell
    UpdateSecureButton(
        badges.rf.clickBtn,
        rfMacro,
        rfMacro,
        scale,
        baseX + (badges.rf.offsetX or 0),
        baseY + (badges.rf.offsetY or 4),
        frameVisible and badges.rf:IsShown()
    )

    -- 2. Aura macro ([noform] guarantees clicking never toggles an active aura off)
    local aura1 = (db and db.lastAuraName) or defAura1
    local aura2 = (aura1 == defAura2) and defAura1 or defAura2
    UpdateSecureButton(
        badges.aura.clickBtn,
        "/cast [noform] " .. aura1,
        "/cast [noform] " .. aura2,
        scale,
        baseX + (badges.aura.offsetX or 0),
        baseY + (badges.aura.offsetY or 4),
        frameVisible and badges.aura:IsShown()
    )

    -- 3. Blessing macro ([@player] casts max rank on self without losing hostile target)
    local bless1 = (db and db.lastBlessingName) or defBless1
    local bless2 = (bless1 == defBless2) and defBless1 or defBless2
    UpdateSecureButton(
        badges.blessing.clickBtn,
        "/cast [@player] " .. bless1,
        "/cast [@player] " .. bless2,
        scale,
        baseX + (badges.blessing.offsetX or 0),
        baseY + (badges.blessing.offsetY or 4),
        frameVisible and badges.blessing:IsShown()
    )
end

local function ApplyPosition()
    if not db then return end
    frame:ClearAllPoints()
    frame:SetScale(db.scale or 0.85)
    frame:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, db.y or 140)
    frame:EnableMouse(unlocked)
    moverBg:SetShown(unlocked)
    moverText:SetShown(unlocked)
    SyncSecureButtons()
end

frame:SetScript("OnDragStart", function(self)
    if unlocked then self:StartMoving() end
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local centerX, centerY = self:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    local scale = self:GetScale()
    if centerX and centerY and parentX and parentY and scale and scale > 0 then
        db.x = centerX - parentX / scale
        db.y = centerY - parentY / scale
    end
    ApplyPosition()
end)

frame:SetScript("OnMouseUp", function(_, button)
    if unlocked and button == "RightButton" then
        unlocked = false
        ApplyPosition()
        Render()
        Message(L("MSG_MOVE_OFF"))
    end
end)

-- Query helper using C_UnitAuras
local function QuerySpellGroup(namesTable)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then
        return nil, true
    end
    local anyRestricted = false
    for name in pairs(namesTable) do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
        if not ok or not IsReadable(aura) then
            anyRestricted = true
        elseif aura then
            return aura, false
        end
    end
    return nil, anyRestricted
end

local function ScanAllBuffs()
    local now = GetTime()
    DetectPaladinSpec()

    -- 1. Check Aura via Shapeshift Form (100% reliable in and out of combat) + buff fallback
    local form = GetShapeshiftForm and GetShapeshiftForm() or 0
    if IsFiniteNumber(form) and form > 0 then
        tracked.aura.active = true
        local icon, _, _, spellID = GetShapeshiftFormInfo and GetShapeshiftFormInfo(form)
        if IsReadable(icon) and icon then tracked.aura.icon = icon end
        if IsFiniteNumber(spellID) and C_Spell and C_Spell.GetSpellName then
            local formName = C_Spell.GetSpellName(spellID)
            if IsReadableString(formName) and formName ~= "" and db then
                db.lastAuraName = formName
            end
        end
    else
        local auraData = QuerySpellGroup(auraNames)
        if auraData then
            tracked.aura.active = true
            if IsReadable(auraData.icon) and auraData.icon then tracked.aura.icon = auraData.icon end
        else
            tracked.aura.active = false
        end
    end

    -- 2. Check Righteous Fury (Furia justa / recta)
    local rfData, rfRestricted = QuerySpellGroup(rfNames)
    if rfData then
        tracked.rf.active = true
        if IsReadable(rfData.icon) and rfData.icon then tracked.rf.icon = rfData.icon end
        if IsReadableString(rfData.name) and rfData.name ~= "" and db then
            db.lastRFName = rfData.name
        end
        if IsFiniteNumber(rfData.expirationTime) and rfData.expirationTime > 0 then
            tracked.rf.expirationTime = rfData.expirationTime
        end
        if IsFiniteNumber(rfData.auraInstanceID) then
            tracked.rf.instanceID = rfData.auraInstanceID
        end
    elseif not inCombat then
        if not rfRestricted then
            tracked.rf.active = false
            tracked.rf.expirationTime = 0
            tracked.rf.instanceID = nil
        end
    else
        if tracked.rf.active and tracked.rf.expirationTime > 0 and tracked.rf.expirationTime <= now then
            tracked.rf.active = false
        end
    end

    -- 3. Check Blessing (Bendición)
    local blessData, blessRestricted = QuerySpellGroup(blessingNames)
    if not blessData and not inCombat and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not ok or not IsReadable(aura) or not aura then break end
            if IsBlessingName(aura.name) then
                blessData = aura
                break
            end
        end
    end

    if blessData then
        tracked.blessing.active = true
        if IsReadable(blessData.icon) and blessData.icon then
            tracked.blessing.icon = blessData.icon
        end
        if IsReadableString(blessData.name) and blessData.name ~= "" and db then
            db.lastBlessingName = blessData.name
        end
        if IsFiniteNumber(blessData.expirationTime) and blessData.expirationTime > 0 then
            tracked.blessing.expirationTime = blessData.expirationTime
        end
        if IsFiniteNumber(blessData.duration) and blessData.duration > 0 then
            tracked.blessing.duration = blessData.duration
        end
        if IsFiniteNumber(blessData.auraInstanceID) then
            tracked.blessing.instanceID = blessData.auraInstanceID
        end
    elseif not inCombat then
        if not blessRestricted then
            tracked.blessing.active = false
            tracked.blessing.expirationTime = 0
            tracked.blessing.instanceID = nil
        end
    else
        if tracked.blessing.active and tracked.blessing.expirationTime > 0 and tracked.blessing.expirationTime <= now then
            tracked.blessing.active = false
        end
    end
end

local function ShouldSuppressAll()
    if unlocked then return false end
    if GetTime() < previewUntil then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return true end
    if UnitOnTaxi and UnitOnTaxi("player") then return true end
    if UnitInVehicle and UnitInVehicle("player") then return true end
    if db.combatOnly and not inCombat then return true end
    return false
end

local function StyleBadgeState(badge, state, remaining)
    badge.label:SetShown(db.showLabels ~= false)
    if state == "expiring" then
        badge.icon:SetVertexColor(1, 1, 1)
        badge.border:SetVertexColor(1, 0.78, 0.25)
        badge.glow:SetVertexColor(1, 0.75, 0.2)
        badge.badgeMark:Hide()
        badge.timer:SetText(tostring(math.ceil(remaining)))
        badge.timer:SetTextColor(1, 0.85, 0.25)
        if not badge.pulse:IsPlaying() then badge.pulse:Play() end
        if badge.bounce:IsPlaying() then badge.bounce:Stop() end
    else
        -- Missing state: slight dim + exclamation mark + combat urgency
        badge.icon:SetVertexColor(0.86, 0.86, 0.86)
        if inCombat then
            badge.border:SetVertexColor(1, 0.35, 0.2)
            badge.glow:SetVertexColor(1, 0.35, 0.15)
            if not badge.bounce:IsPlaying() then badge.bounce:Play() end
        else
            badge.border:SetVertexColor(1, 0.78, 0.28)
            badge.glow:SetVertexColor(1, 0.72, 0.2)
            if badge.bounce:IsPlaying() then badge.bounce:Stop() end
        end
        badge.timer:SetText("")
        badge.badgeMark:Show()
        if not badge.pulse:IsPlaying() then badge.pulse:Play() end
    end
end

Render = function()
    if not db then return end
    if ShouldSuppressAll() then
        frame:Hide()
        SyncSecureButtons()
        return
    end

    local now = GetTime()
    local isPreview = unlocked or (now < previewUntil)
    wipe(activeBadges)

    -- 1. Righteous Fury (only tracked in Protection talents when rfMode == "auto", or always if rfMode == "on")
    if ShouldTrackRF() or unlocked then
        badges.rf.icon:SetTexture(tracked.rf.icon or DEFAULT_ICONS.rf)
        if isPreview or not tracked.rf.active then
            StyleBadgeState(badges.rf, "missing", 0)
            activeBadges[#activeBadges + 1] = badges.rf
        else
            badges.rf.pulse:Stop()
            badges.rf.bounce:Stop()
            badges.rf:Hide()
        end
    else
        badges.rf.pulse:Stop()
        badges.rf.bounce:Stop()
        badges.rf:Hide()
    end

    -- 2. Aura (all 3 specs: Holy, Protection, Retribution)
    if db.trackAura ~= false then
        badges.aura.icon:SetTexture(tracked.aura.icon or DEFAULT_ICONS.aura)
        if isPreview or not tracked.aura.active then
            StyleBadgeState(badges.aura, "missing", 0)
            activeBadges[#activeBadges + 1] = badges.aura
        else
            badges.aura.pulse:Stop()
            badges.aura.bounce:Stop()
            badges.aura:Hide()
        end
    else
        badges.aura:Hide()
    end

    -- 3. Blessing (all 3 specs: Holy, Protection, Retribution)
    if db.trackBlessing ~= false then
        badges.blessing.icon:SetTexture(tracked.blessing.icon or DEFAULT_ICONS.blessing)
        local rem = (tracked.blessing.expirationTime or 0) - now
        if isPreview or not tracked.blessing.active then
            StyleBadgeState(badges.blessing, "missing", 0)
            activeBadges[#activeBadges + 1] = badges.blessing
        elseif tracked.blessing.expirationTime > 0 and rem > 0 and rem <= (db.blessingWarn or 30) then
            StyleBadgeState(badges.blessing, "expiring", rem)
            activeBadges[#activeBadges + 1] = badges.blessing
        else
            badges.blessing.pulse:Stop()
            badges.blessing.bounce:Stop()
            badges.blessing:Hide()
        end
    else
        badges.blessing:Hide()
    end

    local count = #activeBadges
    if count == 0 then
        frame:Hide()
        SyncSecureButtons()
        return
    end

    -- Dynamically center the visible badges horizontally
    local totalWidth = count * ICON_SIZE + (count - 1) * ICON_GAP
    local startX = -totalWidth / 2 + ICON_SIZE / 2
    for i, badge in ipairs(activeBadges) do
        local ox = startX + (i - 1) * (ICON_SIZE + ICON_GAP)
        badge.offsetX = ox
        badge.offsetY = 4
        badge:ClearAllPoints()
        badge:SetPoint("CENTER", frame, "CENTER", ox, 4)
        badge:Show()
    end

    frame:Show()
    SyncSecureButtons()
end

driver:SetScript("OnUpdate", function(_, elapsed)
    if not db then return end
    pollElapsed = pollElapsed + elapsed
    if pollElapsed >= 0.5 then
        pollElapsed = 0
        ScanAllBuffs()
    end
    renderElapsed = renderElapsed + elapsed
    if renderElapsed >= 0.1 then
        renderElapsed = 0
        Render()
    end
end)

-- Handle UNIT_AURA delta updates for combat responsiveness
local function HandleAuraDelta(updateInfo)
    if not IsReadable(updateInfo) or type(updateInfo) ~= "table" then return end
    local now = GetTime()

    local removed = updateInfo.removedAuraInstanceIDs
    if IsReadable(removed) and type(removed) == "table" then
        for _, id in ipairs(removed) do
            if IsFiniteNumber(id) then
                if tracked.rf.instanceID and id == tracked.rf.instanceID then
                    tracked.rf.active = false
                    tracked.rf.instanceID = nil
                end
                if tracked.blessing.instanceID and id == tracked.blessing.instanceID then
                    tracked.blessing.active = false
                    tracked.blessing.instanceID = nil
                end
            end
        end
    end

    local added = updateInfo.addedAuras
    if IsReadable(added) and type(added) == "table" then
        for _, aura in ipairs(added) do
            if IsReadable(aura) and type(aura) == "table" and IsReadableString(aura.name) then
                if rfNames[aura.name] then
                    tracked.rf.active = true
                    tracked.rf.expirationTime = IsFiniteNumber(aura.expirationTime) and aura.expirationTime or (now + 1800)
                    tracked.rf.instanceID = IsFiniteNumber(aura.auraInstanceID) and aura.auraInstanceID or nil
                    if IsReadable(aura.icon) and aura.icon then tracked.rf.icon = aura.icon end
                    if db then db.lastRFName = aura.name end
                elseif auraNames[aura.name] then
                    tracked.aura.active = true
                    if IsReadable(aura.icon) and aura.icon then tracked.aura.icon = aura.icon end
                    if db then db.lastAuraName = aura.name end
                elseif IsBlessingName(aura.name) then
                    tracked.blessing.active = true
                    tracked.blessing.expirationTime = IsFiniteNumber(aura.expirationTime) and aura.expirationTime or (now + 300)
                    tracked.blessing.instanceID = IsFiniteNumber(aura.auraInstanceID) and aura.auraInstanceID or nil
                    if IsReadable(aura.icon) and aura.icon then tracked.blessing.icon = aura.icon end
                    if db then db.lastBlessingName = aura.name end
                end
            end
        end
    end
end

local function EnsureDB()
    -- Migrate from legacy ForeverFuryAlertDB if present
    if type(BuffGuardDB) ~= "table" and type(ForeverFuryAlertDB) == "table" then
        BuffGuardDB = ForeverFuryAlertDB
    end
    BuffGuardDB = type(BuffGuardDB) == "table" and BuffGuardDB or {}
    db = BuffGuardDB
    if type(db.x) ~= "number" then db.x = 0 end
    if type(db.y) ~= "number" then db.y = 140 end
    if type(db.scale) ~= "number" then db.scale = 0.85 end
    if type(db.rfMode) ~= "string" then
        if db.trackRF == false then
            db.rfMode = "off"
        else
            db.rfMode = "auto"
        end
    end
    if db.trackAura == nil then db.trackAura = true end
    if db.trackBlessing == nil then db.trackBlessing = true end
    if db.showLabels == nil then db.showLabels = true end
    if db.combatOnly == nil then db.combatOnly = false end
    if type(db.blessingWarn) ~= "number" then db.blessingWarn = 30 end
    return db
end

local function GetLocalizedSpecName()
    if currentSpec == "holy" then return L("SPEC_HOLY") end
    if currentSpec == "protection" then return L("SPEC_PROTECTION") end
    if currentSpec == "retribution" then return L("SPEC_RETRIBUTION") end
    return L("SPEC_NONE")
end

SLASH_BUFFGUARD1 = "/buffguard"
SLASH_BUFFGUARD2 = "/bguard"
SLASH_BUFFGUARD3 = "/furia"
SLASH_BUFFGUARD4 = "/fa"
SlashCmdList["BUFFGUARD"] = function(msg)
    EnsureDB()
    local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    arg = (arg or ""):lower()

    if cmd == "" or cmd == "move" or cmd == "mover" or cmd == "unlock" or cmd == "lock" then
        if InCombat() then
            Message(L("MSG_COMBAT_LOCK"))
            return
        end
        if cmd == "lock" then
            unlocked = false
        elseif cmd == "unlock" then
            unlocked = true
        else
            unlocked = not unlocked
        end
        ApplyPosition()
        Render()
        if unlocked then
            Message(L("MSG_MOVE_ON"))
        else
            Message(L("MSG_MOVE_OFF"))
        end
    elseif cmd == "status" or cmd == "info" or cmd == "spec" or cmd == "rama" then
        DetectPaladinSpec()
        local rfState = ShouldTrackRF() and L("STATE_ACTIVE") or L("STATE_INACTIVE")
        Message(string.format(
            L("MSG_STATUS"),
            GetLocalizedSpecName(),
            talentPoints[1], talentPoints[2], talentPoints[3],
            (db.rfMode or "auto"):upper(),
            rfState
        ))
    elseif cmd == "scale" or cmd == "size" or cmd == "tamano" then
        local val = tonumber(arg)
        if val and val >= 0.4 and val <= 2.0 then
            db.scale = val
            ApplyPosition()
            Render()
            Message(string.format(L("MSG_SCALE_SET"), tostring(val)))
        else
            Message(L("MSG_SCALE_USAGE"))
        end
    elseif cmd == "texto" or cmd == "text" or cmd == "labels" then
        db.showLabels = not (db.showLabels ~= false)
        Render()
        Message(db.showLabels and L("MSG_LABELS_ON") or L("MSG_LABELS_OFF"))
    elseif cmd == "combate" or cmd == "combat" then
        db.combatOnly = not db.combatOnly
        Render()
        Message(db.combatOnly and L("MSG_COMBAT_ONLY_ON") or L("MSG_COMBAT_ONLY_OFF"))
    elseif cmd == "rf" or cmd == "furia" or cmd == "fury" then
        if arg == "auto" then
            db.rfMode = "auto"
        elseif arg == "on" or arg == "si" or arg == "always" then
            db.rfMode = "on"
        elseif arg == "off" or arg == "no" then
            db.rfMode = "off"
        else
            -- Cycle: auto -> on -> off -> auto
            if db.rfMode == "auto" then
                db.rfMode = "on"
            elseif db.rfMode == "on" then
                db.rfMode = "off"
            else
                db.rfMode = "auto"
            end
        end
        Render()
        if db.rfMode == "auto" then
            Message(L("MSG_RF_AUTO"))
        elseif db.rfMode == "on" then
            Message(L("MSG_RF_ON"))
        else
            Message(L("MSG_RF_OFF"))
        end
    elseif cmd == "aura" then
        db.trackAura = not (db.trackAura ~= false)
        Render()
        Message(db.trackAura and L("MSG_AURA_ON") or L("MSG_AURA_OFF"))
    elseif cmd == "bendicion" or cmd == "blessing" then
        db.trackBlessing = not (db.trackBlessing ~= false)
        Render()
        Message(db.trackBlessing and L("MSG_BLESS_ON") or L("MSG_BLESS_OFF"))
    elseif cmd == "lang" or cmd == "idioma" or cmd == "locale" then
        if arg == "es" or arg == "eses" then
            db.lang = "es"
        elseif arg == "en" or arg == "enus" then
            db.lang = "en"
        else
            db.lang = (GetLang() == "es") and "en" or "es"
        end
        RefreshBadgeLabels()
        Render()
        Message(L("MSG_LANG_SET"))
    elseif cmd == "reset" then
        db.x, db.y, db.scale = 0, 140, 0.85
        db.rfMode = "auto"
        db.trackAura = true
        db.trackBlessing = true
        ApplyPosition()
        Render()
        Message(L("MSG_RESET"))
    else
        Message(L("MSG_HELP"))
    end
end

local TALENT_EVENTS = {
    "TRAIT_CONFIG_UPDATED",
    "PLAYER_TALENT_UPDATE",
    "CHARACTER_POINTS_CHANGED",
    "ACTIVE_TALENT_GROUP_CHANGED",
    "PLAYER_LEVEL_UP",
}

driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
    if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
        if event == "ADDON_LOADED" and unit ~= addonName then return end
        local _, class = UnitClass("player")
        if class and class ~= "PALADIN" then
            driver:UnregisterAllEvents()
            driver:SetScript("OnUpdate", nil)
            return
        end

        EnsureDB()
        RefreshBadgeLabels()
        BuildSpellNames()
        DetectPaladinSpec()
        ApplyPosition()

        driver:RegisterEvent("PLAYER_ENTERING_WORLD")
        driver:RegisterEvent("UNIT_AURA")
        driver:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        driver:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
        driver:RegisterEvent("PLAYER_REGEN_DISABLED")
        driver:RegisterEvent("PLAYER_REGEN_ENABLED")
        driver:RegisterEvent("PLAYER_DEAD")
        driver:RegisterEvent("PLAYER_ALIVE")
        driver:RegisterEvent("PLAYER_UNGHOST")
        driver:RegisterEvent("SPELLS_CHANGED")
        for _, tev in ipairs(TALENT_EVENTS) do
            pcall(driver.RegisterEvent, driver, tev)
        end

        inCombat = UnitAffectingCombat and UnitAffectingCombat("player") == true
        ScanAllBuffs()
        Render()
    elseif event == "PLAYER_ENTERING_WORLD" then
        RefreshBadgeLabels()
        BuildSpellNames()
        DetectPaladinSpec()
        inCombat = UnitAffectingCombat and UnitAffectingCombat("player") == true
        ApplyPosition()
        ScanAllBuffs()
        if not db.welcomed then
            db.welcomed = true
            previewUntil = GetTime() + 4
            Message(L("MSG_WELCOME"))
        end
        Render()
    elseif event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_TALENT_UPDATE"
        or event == "CHARACTER_POINTS_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED"
        or event == "PLAYER_LEVEL_UP" then
        DetectPaladinSpec()
        ScanAllBuffs()
        Render()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit ~= "player" or not IsFiniteNumber(spellID) then return end
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
        local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
        local now = GetTime()

        if spellID == 25780 or (IsReadableString(name) and rfNames[name]) then
            tracked.rf.active = true
            tracked.rf.expirationTime = now + 1800
            if IsReadable(tex) and tex then tracked.rf.icon = tex end
            if IsReadableString(name) and db then db.lastRFName = name end
            Render()
        elseif IsReadableString(name) and auraNames[name] then
            tracked.aura.active = true
            if IsReadable(tex) and tex then tracked.aura.icon = tex end
            if db then db.lastAuraName = name end
            Render()
        elseif IsReadableString(name) and IsBlessingName(name) then
            tracked.blessing.active = true
            local dur = (name:find("superior") or name:find("Greater")) and 900 or 300
            tracked.blessing.duration = dur
            tracked.blessing.expirationTime = now + dur
            if IsReadable(tex) and tex then tracked.blessing.icon = tex end
            if db then db.lastBlessingName = name end
            Render()
        end
    elseif event == "UNIT_AURA" then
        if unit == "player" then
            HandleAuraDelta(castGUID)
            ScanAllBuffs()
            Render()
        end
    elseif event == "UPDATE_SHAPESHIFT_FORM" or event == "SPELLS_CHANGED" then
        BuildSpellNames()
        DetectPaladinSpec()
        ScanAllBuffs()
        Render()
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        ScanAllBuffs()
        Render()
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        ScanAllBuffs()
        Render()
        if pendingSecureSync then
            SyncSecureButtons()
        end
    elseif event == "PLAYER_DEAD" then
        tracked.rf.active = false
        tracked.blessing.active = false
        Render()
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        ScanAllBuffs()
        Render()
    end
end)
