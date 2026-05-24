---@class addon
local addon = select(2, ...)
local L = addon.L

-- Lua API
-----------------------------------------------------------
local math = math

-- WoW API
-----------------------------------------------------------
local _G = _G
local CreateFrame   = _G.CreateFrame
local C_Timer       = _G.C_Timer
local IsPlayerSpell = _G.IsPlayerSpell

-- Spell IDs
-----------------------------------------------------------
-- Disintegrate normal (Devastation/Augmentation)
local DISINTEGRATE_ID      = 356995
-- Mass Disintegrate (Scalecommander hero talent) — sempre 4 ticks, ignora Azure Celerity
local MASS_DISINTEGRATE_ID = 436336
-- Azure Celerity: adiciona um 5º tick ao Disintegrate normal
local AZURE_CELERITY_ID    = 1219723

-- Mapeamento spellID → isMass (para resolver rapidamente o canal ativo)
local CHANNEL_LOOKUP = {
	[DISINTEGRATE_ID]      = false,
	[MASS_DISINTEGRATE_ID] = true,
}

-- Estado de runtime
-----------------------------------------------------------
local overlayFrame     ---@type Frame?
local tickMarkers      = {}  -- texturas verticais nos ticks (1..N)
local segmentOverlays  = {}  -- texturas de segmento (entre ticks k e k+1, k=1..N-1)
local massWarningGlow  ---@type Texture?
local widgetsCreated   = false

-- Cache de talento (revalidado por eventos)
local hasAzureCelerityCached = false

-- Frame privado para eventos de talento (evita conflito com addon.OnEvent
-- do Visibility, que também escuta PLAYER_ENTERING_WORLD).
local talentEventFrame  ---@type Frame?

-- Helpers
-----------------------------------------------------------
local function GetCastBar()
	return _G["PlayerCastingBarFrame"] or _G["CastingBarFrame"]
end

local function HasAzureCelerity()
	return hasAzureCelerityCached
end

local function RefreshTalentCache()
	hasAzureCelerityCached = (IsPlayerSpell and IsPlayerSpell(AZURE_CELERITY_ID)) and true or false
end

-- Resolve número de ticks do canal ativo
local function GetNumTicks(isMass)
	if isMass then return 4 end
	return HasAzureCelerity() and 5 or 4
end

-- Custo de clip (0..1) para o segmento k (entre tick k e tick k+1, contando 1..N-1):
--   segmento N-1 (mais à esquerda) → 0 (chain limpo)
--   segmento N-2                   → ~0.15 (1 tick clipado)
--   segmentos anteriores           → cresce até 1 (clip pesado)
-- Retorna (r, g, b) para um overlay semi-transparente.
local function ClipCostColor(segmentIndex, numTicks)
	-- ticksClipped = quantos ticks restavam quando o usuário cortaria aqui.
	-- Se chainar no segmento k (entre tick k e k+1), perde ticks k+1..N-1
	-- (o tick k já bateu, o tick N é "absorvido" pelo próximo cast).
	local ticksClipped = math.max(0, (numTicks - 1) - segmentIndex)
	if ticksClipped == 0 then
		return 0.1, 1.0, 0.1  -- verde
	end

	-- Normaliza: 1 tick perdido = pequeno, (N-2) ticks = total
	local maxClippable = math.max(1, numTicks - 2)
	local t = math.min(1, ticksClipped / maxClippable)

	-- t=0 → amarelo (1, 1, 0); t=1 → vermelho (1, 0, 0)
	local r = 1.0
	local g = 1.0 - t
	local b = 0.0
	return r, g, b
end

-- Cria o frame overlay e pools de texturas (uma única vez)
-----------------------------------------------------------
-- Texturas filhas diretas de um StatusBar ficam atrás dos seus frames-filhos
-- (borda/chrome). Usamos um Frame separado com strata DIALOG para garantir
-- que tudo apareça por cima.
local MAX_TICKS = 6  -- 5 com Azure Celerity + folga

local function EnsureWidgets()
	if widgetsCreated then return true end
	local bar = GetCastBar()
	if not bar then return false end

	overlayFrame = CreateFrame("Frame", nil, bar)
	overlayFrame:SetAllPoints(bar)
	overlayFrame:SetFrameStrata("DIALOG")
	overlayFrame:SetFrameLevel(1)

	for i = 1, MAX_TICKS do
		local m = overlayFrame:CreateTexture(nil, "OVERLAY", nil, 7)
		m:SetColorTexture(1, 1, 1, 1)
		m:Hide()
		tickMarkers[i] = m
	end

	for i = 1, MAX_TICKS - 1 do
		local s = overlayFrame:CreateTexture(nil, "ARTWORK", nil, 3)
		s:Hide()
		segmentOverlays[i] = s
	end

	massWarningGlow = overlayFrame:CreateTexture(nil, "ARTWORK", nil, 2)
	massWarningGlow:SetColorTexture(1.0, 0.2, 0.2, 0.18)
	massWarningGlow:Hide()

	widgetsCreated = true
	return true
end

local function HideAll()
	for i = 1, MAX_TICKS do
		if tickMarkers[i] then tickMarkers[i]:Hide() end
	end
	for i = 1, MAX_TICKS - 1 do
		if segmentOverlays[i] then segmentOverlays[i]:Hide() end
	end
	if massWarningGlow then massWarningGlow:Hide() end
end

-- Desenha marcadores e segmentos
-----------------------------------------------------------
-- A barra de canal esvazia da DIREITA → ESQUERDA:
--   tick 1 (instantâneo no cast)  → borda direita  (posição barW)
--   tick N (fim do canal)         → borda esquerda (posição 0)
--   tick i → posição barW * (N - i) / (N - 1) a partir da borda esquerda
local function ShowChannel(numTicks, isMass)
	if not EnsureWidgets() then return end
	local db = addon.db
	if not db or not db.evokerDisintegrateMarkers then
		HideAll()
		return
	end

	local bar = GetCastBar()
	local barW = bar:GetWidth()
	local barH = bar:GetHeight()
	if barW <= 0 then return end

	HideAll()

	local N = numTicks
	local opacity = db.evokerChainOverlayOpacity
	if type(opacity) ~= "number" then opacity = 0.25 end
	local suppressChain = isMass and db.evokerMassDisintegrateWarning
	local showGradient = db.evokerDisintegrateClipGradient

	-- Segmentos (entre ticks k e k+1, k=1..N-1) — coloridos por custo de clip
	for k = 1, N - 1 do
		local seg = segmentOverlays[k]
		if seg then
			local isChainSegment = (k == N - 1)
			local r, g, b
			local draw = false

			if isChainSegment and suppressChain then
				-- Mass Disintegrate: aviso em vez da zona verde
				r, g, b = 1.0, 0.2, 0.2
				draw = true
			elseif showGradient then
				r, g, b = ClipCostColor(k, N)
				draw = true
			elseif isChainSegment then
				-- Sem gradiente: só desenha a zona verde de chain
				r, g, b = 0.1, 1.0, 0.1
				draw = true
			end

			if draw then
				local rightX = barW * (N - k) / (N - 1)     -- posição do tick k
				local leftX  = barW * (N - k - 1) / (N - 1) -- posição do tick k+1
				seg:SetColorTexture(r, g, b, opacity)
				seg:ClearAllPoints()
				seg:SetPoint("BOTTOMLEFT", overlayFrame, "BOTTOMLEFT", leftX, 0)
				seg:SetPoint("TOPRIGHT",   overlayFrame, "BOTTOMLEFT", rightX, barH)
				seg:Show()
			else
				seg:Hide()
			end
		end
	end

	-- Mass Disintegrate: glow vermelho sutil sobre toda a barra
	if isMass and db.evokerMassDisintegrateWarning and massWarningGlow then
		massWarningGlow:ClearAllPoints()
		massWarningGlow:SetAllPoints(overlayFrame)
		massWarningGlow:Show()
	end

	-- Marcadores verticais nos ticks (1..N)
	local markerHeight = math.max(barH, 10)
	for i = 1, N do
		local m = tickMarkers[i]
		if m then
			local x = barW * (N - i) / (N - 1)
			local isBoundary = (i == 1 or i == N)
			local isChain = (i == N - 1)  -- penúltimo tick = início da zona de chain
			m:SetSize(isChain and 3 or 2, markerHeight)
			-- Tick 1: branco (início). Tick N: branco forte. Chain (N-1): verde brilhante.
			if isChain and not (isMass and db.evokerMassDisintegrateWarning) then
				m:SetColorTexture(0.4, 1.0, 0.4, 1.0)
			elseif isBoundary then
				m:SetColorTexture(1.0, 1.0, 1.0, 0.9)
			else
				m:SetColorTexture(1.0, 1.0, 1.0, 0.7)
			end
			m:ClearAllPoints()
			m:SetPoint("CENTER", overlayFrame, "LEFT", x, 0)
			m:Show()
		end
	end
end

-- Event handlers (despachados pelo nome via Environment.lua)
-----------------------------------------------------------
local function ResolveChannel(spellID)
	return CHANNEL_LOOKUP[spellID]
end

function addon:UNIT_SPELLCAST_CHANNEL_START(_, unit, _, spellID)
	if unit ~= "player" then return end
	local isMass = ResolveChannel(spellID)
	if isMass == nil then return end
	-- Pequeno delay para o castbar ter dimensões finais após o evento
	C_Timer.After(0.02, function()
		ShowChannel(GetNumTicks(isMass), isMass)
	end)
end

function addon:UNIT_SPELLCAST_CHANNEL_UPDATE(_, unit, _, spellID)
	if unit ~= "player" then return end
	local isMass = ResolveChannel(spellID)
	if isMass == nil then return end
	ShowChannel(GetNumTicks(isMass), isMass)
end

function addon:UNIT_SPELLCAST_CHANNEL_STOP(_, unit)
	if unit ~= "player" then return end
	HideAll()
end

local function EnsureTalentEventFrame()
	if talentEventFrame then return talentEventFrame end
	talentEventFrame = CreateFrame("Frame")
	talentEventFrame:SetScript("OnEvent", function()
		RefreshTalentCache()
	end)
	return talentEventFrame
end

local function RegisterTalentEvents()
	local f = EnsureTalentEventFrame()
	f:RegisterEvent("PLAYER_TALENT_UPDATE")
	f:RegisterEvent("TRAIT_CONFIG_UPDATED")
	f:RegisterEvent("SPELLS_CHANGED")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
end

local function UnregisterTalentEvents()
	if talentEventFrame then
		talentEventFrame:UnregisterAllEvents()
	end
end

-- Registro do módulo
-----------------------------------------------------------
addon:RegisterModule({
	id             = "evoker",
	name           = L["Evoker"] or "Evoker",
	defaultEnabled = true,
	order          = 20,

	OnEnable = function(_)
		RefreshTalentCache()
		addon:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START",  "player")
		addon:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
		addon:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP",   "player")
		RegisterTalentEvents()
	end,

	OnDisable = function(_)
		HideAll()
		addon:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_START")
		addon:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
		addon:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
		UnregisterTalentEvents()
	end,

	AddSettings = function(_, category, layout)
		local Settings = _G["Settings"]
		if not Settings then return end

		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Disintegrate Chaining"]))

		-- Checkbox: marcadores de tick
		local markerSetting = Settings.RegisterProxySetting(
			category,
			"WoWPersonal_Evoker_DisintegrateMarkers",
			Settings.VarType.Boolean,
			L["Show Disintegrate tick markers"],
			Settings.Default.True,
			function() return addon.db and addon.db.evokerDisintegrateMarkers or false end,
			function(value)
				if addon.db then addon.db.evokerDisintegrateMarkers = value end
				if not value then HideAll() end
			end
		)
		Settings.CreateCheckbox(category, markerSetting, L["Show Disintegrate tick markers tooltip"])

		-- Checkbox: gradiente de clip cost
		local gradientSetting = Settings.RegisterProxySetting(
			category,
			"WoWPersonal_Evoker_ClipGradient",
			Settings.VarType.Boolean,
			L["Show clip cost gradient"],
			Settings.Default.True,
			function() return addon.db and addon.db.evokerDisintegrateClipGradient or false end,
			function(value)
				if addon.db then addon.db.evokerDisintegrateClipGradient = value end
			end
		)
		Settings.CreateCheckbox(category, gradientSetting, L["Show clip cost gradient tooltip"])

		-- Checkbox: aviso de Mass Disintegrate
		local massSetting = Settings.RegisterProxySetting(
			category,
			"WoWPersonal_Evoker_MassWarning",
			Settings.VarType.Boolean,
			L["Warn on Mass Disintegrate chain"],
			Settings.Default.True,
			function() return addon.db and addon.db.evokerMassDisintegrateWarning or false end,
			function(value)
				if addon.db then addon.db.evokerMassDisintegrateWarning = value end
			end
		)
		Settings.CreateCheckbox(category, massSetting, L["Warn on Mass Disintegrate chain tooltip"])

		-- Slider: opacidade do overlay
		local opacitySetting = Settings.RegisterProxySetting(
			category,
			"WoWPersonal_Evoker_ChainOpacity",
			Settings.VarType.Number,
			L["Chain overlay opacity"],
			0.25,
			function()
				local v = addon.db and addon.db.evokerChainOverlayOpacity
				return (type(v) == "number") and v or 0.25
			end,
			function(value)
				if addon.db then addon.db.evokerChainOverlayOpacity = value end
			end
		)
		local opacityOptions = Settings.CreateSliderOptions(0, 1, 0.05)
		opacityOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v)
			return string.format("%.0f%%", v * 100)
		end)
		Settings.CreateSlider(category, opacitySetting, opacityOptions, L["Chain overlay opacity tooltip"])
	end,
})
