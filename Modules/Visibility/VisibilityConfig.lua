---@class addon
local addon = select(2, ...)
local L = addon.L

-- Lua API
-----------------------------------------------------------
local ipairs = ipairs

-- WoW API
-----------------------------------------------------------
local _G = _G
local Settings = _G.Settings

-- Ordem e labels dos cenários
local SCENARIO_ORDER = { "city", "instance_pve", "instance_pvp", "open_world" }
local SCENARIO_LABELS = {
	city         = L["In City"],
	instance_pve = L["In PVE Instance"],
	instance_pvp = L["In PvP Instance"],
	open_world   = L["In Open World"],
}
local SCENARIO_COLORS = {
	city         = "|cFF4FC3F7",
	instance_pve = "|cFF81C784",
	instance_pvp = "|cFFE57373",
	open_world   = "|cFFFFB74D",
}

--- Garante que db.scenarios[key] existe e tem as chaves padrão
---@param db table
---@param key string
---@return table
local function EnsureScenario(db, key)
	if type(db.scenarios) ~= "table" then db.scenarios = {} end
	if type(db.scenarios[key]) ~= "table" then db.scenarios[key] = {} end
	local s = db.scenarios[key]
	if s.enabled == nil then s.enabled = true end
	if s.transparencyInCombat == nil then s.transparencyInCombat = 1.0 end
	if s.transparencyOutOfCombat == nil then s.transparencyOutOfCombat = 1.0 end
	return s
end

-- Contribuição ao painel de configurações do Blizzard
-----------------------------------------------------------
local mod = addon.modules["visibility"]

--- Adiciona as configurações de visibilidade à subcategoria do painel de opções.
---@param category table   Subcategoria registrada via Settings.RegisterVerticalLayoutSubcategory
---@param layout   table   Layout vertical associado à subcategoria
function mod:AddSettings(category, layout)
	if not Settings then return end

	-- Checkbox: modo debug (movido da antiga subcategoria "Geral")
	local function GetDebugValue()
		return addon.db and addon.db.debugMode
	end
	local function SetDebugValue(value)
		if addon.db then addon.db.debugMode = value end
	end
	local debugSetting = Settings.RegisterProxySetting(
		category,
		"WoWPersonal_DebugMode",
		Settings.VarType.Boolean,
		L["Debug Mode"],
		Settings.Default.False,
		GetDebugValue,
		SetDebugValue
	)
	Settings.CreateCheckbox(category, debugSetting, L["Toggle debug output"])

	for _, scenarioKey in ipairs(SCENARIO_ORDER) do
		local label = SCENARIO_LABELS[scenarioKey] or scenarioKey
		local color = SCENARIO_COLORS[scenarioKey] or ""
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(color .. label .. "|r"))

		-- Checkbox: mostrar neste cenário
		local function GetEnabled()
			local db = addon:GetDB()
			local s = EnsureScenario(db, scenarioKey)
			return s.enabled
		end
		local function SetEnabled(value)
			local db = addon:GetDB()
			local s = EnsureScenario(db, scenarioKey)
			s.enabled = value
			if addon.UpdateAllFrameVisibility then addon:UpdateAllFrameVisibility() end
		end
		local enabledSetting = Settings.RegisterProxySetting(
			category,
			"WoWPersonal_Scenario_" .. scenarioKey .. "_Enabled",
			Settings.VarType.Boolean,
			label .. " - " .. L["Show in this scenario"],
			Settings.Default.True,
			GetEnabled,
			SetEnabled
		)
		Settings.CreateCheckbox(category, enabledSetting, L["Show in this scenario"])

		-- Slider: transparência em combate
		local function GetTransparencyInCombat()
			local db = addon:GetDB()
			local s = EnsureScenario(db, scenarioKey)
			return s.transparencyInCombat or 1.0
		end
		local function SetTransparencyInCombat(value)
			local db = addon:GetDB()
			local s = EnsureScenario(db, scenarioKey)
			s.transparencyInCombat = value
			if addon.UpdateAllFrameVisibility then addon:UpdateAllFrameVisibility() end
		end
		local transInSetting = Settings.RegisterProxySetting(
			category,
			"WoWPersonal_Scenario_" .. scenarioKey .. "_TransparencyInCombat",
			Settings.VarType.Number,
			label .. " - " .. L["Transparency"] .. " (Em Combate)",
			Settings.Default.Number,
			GetTransparencyInCombat,
			SetTransparencyInCombat
		)
		local transInOptions = Settings.CreateSliderOptions(0, 1, 0.01)
		transInOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v)
			return string.format("%.0f%%", v * 100)
		end)
		Settings.CreateSlider(category, transInSetting, transInOptions, L["Transparency in combat for this scenario"])

		-- Slider: transparência fora de combate
		local function GetTransparencyOutOfCombat()
			local db = addon:GetDB()
			local s = EnsureScenario(db, scenarioKey)
			return s.transparencyOutOfCombat or 1.0
		end
		local function SetTransparencyOutOfCombat(value)
			local db = addon:GetDB()
			local s = EnsureScenario(db, scenarioKey)
			s.transparencyOutOfCombat = value
			if addon.UpdateAllFrameVisibility then addon:UpdateAllFrameVisibility() end
		end
		local transOutSetting = Settings.RegisterProxySetting(
			category,
			"WoWPersonal_Scenario_" .. scenarioKey .. "_TransparencyOutOfCombat",
			Settings.VarType.Number,
			label .. " - " .. L["Transparency"] .. " (Fora de Combate)",
			Settings.Default.Number,
			GetTransparencyOutOfCombat,
			SetTransparencyOutOfCombat
		)
		local transOutOptions = Settings.CreateSliderOptions(0, 1, 0.01)
		transOutOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v)
			return string.format("%.0f%%", v * 100)
		end)
		Settings.CreateSlider(category, transOutSetting, transOutOptions, L["Transparency out of combat for this scenario"])
	end
end
