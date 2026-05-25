---@class addon
local addon = select(2, ...)
local L = addon.L

-- WoW API
-----------------------------------------------------------
local _G = _G
local CreateFrame = _G.CreateFrame
local UnitPower   = _G.UnitPower
local Enum        = _G.Enum

-- Spell IDs do Disintegrate (Devastation/Augmentation + Mass do Scalecommander)
local DISINTEGRATE_ID      = 356995
local MASS_DISINTEGRATE_ID = 436336

-- Mapeamento spellID → isMass (lookup do canal ativo)
local CHANNEL_LOOKUP = {
	[DISINTEGRATE_ID]      = false,
	[MASS_DISINTEGRATE_ID] = true,
}

-- Custo base do Disintegrate em essência. O módulo NÃO detecta auras de
-- redução de custo (Imminent Destruction, Essence Burst) porque o sistema
-- de "secret values" do retail bloqueia comparações de IDs/strings de aura
-- em código de addon. Mantemos a regra simples: precisa ter custo base.
local DISINTEGRATE_COST = 3

-- Widget abaixo da castbar
local adviceFrame  ---@type Frame?
local adviceBg     ---@type Texture?
local widgetReady  = false

-- Estado de canal
local isChanneling    = false
local currentIsMass   = false

-- Event frame privado: usamos um único frame pra TUDO (canal + power), em
-- vez do dispatcher por nome do Environment.lua. Motivo: o módulo Evoker
-- já define addon:UNIT_SPELLCAST_CHANNEL_START/UPDATE/STOP por esse caminho,
-- e o dispatcher só chama UM handler por evento — definir aqui também
-- sobrescreveria o do Evoker, quebrando os tick markers.
local eventFrame  ---@type Frame?

local function GetCastBar()
	return _G["PlayerCastingBarFrame"] or _G["CastingBarFrame"]
end

local function HideAdvice()
	if adviceFrame then adviceFrame:Hide() end
end

local function EnsureWidget()
	if widgetReady then return true end
	local bar = GetCastBar()
	if not bar then return false end

	adviceFrame = CreateFrame("Frame", nil, bar)
	adviceFrame:SetPoint("TOPLEFT",  bar, "BOTTOMLEFT",  0, -2)
	adviceFrame:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -2)
	adviceFrame:SetHeight(12)
	adviceFrame:SetFrameStrata("MEDIUM")
	adviceFrame:Hide()

	adviceBg = adviceFrame:CreateTexture(nil, "BACKGROUND")
	adviceBg:SetAllPoints(adviceFrame)
	adviceBg:SetColorTexture(0.1, 0.8, 0.1, 0.7)

	widgetReady = true
	return true
end

-- Regra:
--   - Durante Mass Disintegrate: sempre vermelho (Mass nunca deve ser clipado).
--   - Durante Disintegrate normal: verde se essência atual >= custo (3),
--     vermelho caso contrário.
local function UpdateAdvice()
	if not isChanneling then
		HideAdvice()
		return
	end
	local db = addon.db
	if not db or not db.clipAdviceEnabled then
		HideAdvice()
		return
	end
	if not EnsureWidget() then return end

	local ok
	if currentIsMass then
		ok = false
	else
		local powerType = (Enum and Enum.PowerType and Enum.PowerType.Essence) or 19
		local cur = UnitPower("player", powerType) or 0
		ok = (cur >= DISINTEGRATE_COST)
	end

	if ok then
		adviceBg:SetColorTexture(0.1, 0.8, 0.1, 0.7)
	else
		adviceBg:SetColorTexture(0.9, 0.2, 0.2, 0.7)
	end
	adviceFrame:Show()
end

-- Event handling via frame privado
-----------------------------------------------------------
local function OnChannelStart(unit, _, spellID)
	if unit ~= "player" then return end
	local isMass = CHANNEL_LOOKUP[spellID]
	if isMass == nil then return end
	isChanneling = true
	currentIsMass = isMass
	UpdateAdvice()
end

local function OnChannelUpdate(unit, _, spellID)
	if unit ~= "player" then return end
	local isMass = CHANNEL_LOOKUP[spellID]
	if isMass == nil then return end
	currentIsMass = isMass
	UpdateAdvice()
end

local function OnChannelStop(unit)
	if unit ~= "player" then return end
	isChanneling = false
	currentIsMass = false
	HideAdvice()
end

local EVENT_DISPATCH = {
	UNIT_SPELLCAST_CHANNEL_START  = OnChannelStart,
	UNIT_SPELLCAST_CHANNEL_UPDATE = OnChannelUpdate,
	UNIT_SPELLCAST_CHANNEL_STOP   = OnChannelStop,
	UNIT_POWER_UPDATE             = function() if isChanneling then UpdateAdvice() end end,
	UNIT_POWER_FREQUENT           = function() if isChanneling then UpdateAdvice() end end,
}

local function EnsureEventFrame()
	if eventFrame then return eventFrame end
	eventFrame = CreateFrame("Frame")
	eventFrame:SetScript("OnEvent", function(_, event, ...)
		local handler = EVENT_DISPATCH[event]
		if handler then handler(...) end
	end)
	return eventFrame
end

local function RegisterEvents()
	local f = EnsureEventFrame()
	f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START",  "player")
	f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
	f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP",   "player")
	f:RegisterUnitEvent("UNIT_POWER_UPDATE",   "player")
	f:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
end

local function UnregisterEvents()
	if eventFrame then eventFrame:UnregisterAllEvents() end
end

-- Registro do módulo
-----------------------------------------------------------
addon:RegisterModule({
	id             = "clipAdvice",
	name           = L["Clip Advice"] or "Conselho de Clip (Disintegrate)",
	defaultEnabled = true,
	order          = 30,

	OnEnable = function(_)
		RegisterEvents()
	end,

	OnDisable = function(_)
		isChanneling = false
		HideAdvice()
		UnregisterEvents()
	end,

	AddSettings = function(_, category, layout)
		local Settings = _G["Settings"]
		if not Settings then return end

		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(
			L["Disintegrate Clip Advice"] or "Conselho de Clip do Desintegrar"
		))

		local enableSetting = Settings.RegisterProxySetting(
			category,
			"WoWPersonal_ClipAdvice_Enabled",
			Settings.VarType.Boolean,
			L["Show clip advice indicator"] or "Mostrar indicador de clip",
			Settings.Default.True,
			function() return addon.db and addon.db.clipAdviceEnabled or false end,
			function(value)
				if addon.db then addon.db.clipAdviceEnabled = value end
				if not value then
					HideAdvice()
				elseif isChanneling then
					UpdateAdvice()
				end
			end
		)
		Settings.CreateCheckbox(category, enableSetting,
			L["Show clip advice indicator tooltip"] or
			"Mostra uma barra abaixo da castbar durante o Disintegrate: verde quando há essência suficiente (3+) para chainar/clippar o próximo cast, vermelho quando não há ou durante Mass Disintegrate.")
	end,
})
