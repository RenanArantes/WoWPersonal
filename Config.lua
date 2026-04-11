---@class addon
local addon = select(2, ...)
local L = addon.L

-- Lua API
-----------------------------------------------------------
local ipairs = ipairs
local pairs = pairs
local table = table

-- WoW API
-----------------------------------------------------------
local _G = _G

-- Painel de configurações (AddOns > WoWPersonal nas Opções do jogo)
-----------------------------------------------------------

--- Cria a categoria principal (só texto descritivo) e uma subcategoria por módulo.
function addon:CreateConfigPanel()
	local Settings = _G["Settings"]
	if not Settings then return end

	-- Categoria principal: apenas texto descritivo
	local category, layout = Settings.RegisterVerticalLayoutCategory("WoWPersonal")
	addon.category = category:GetID()
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(
		"Addon de qualidade de vida para World of Warcraft."
	))
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(
		"Selecione uma funcionalidade ao lado para configurar."
	))
	Settings.RegisterAddOnCategory(category)

	-- Subcategoria "Geral": configurações globais do addon
	local generalCat = Settings.RegisterVerticalLayoutSubcategory(category, L["General"] or "Geral")
	Settings.RegisterAddOnCategory(generalCat)

	local function GetDebugValue()
		return addon.db and addon.db.debugMode
	end
	local function SetDebugValue(value)
		if addon.db then addon.db.debugMode = value end
	end
	local debugSetting = Settings.RegisterProxySetting(
		generalCat,
		"WoWPersonal_DebugMode",
		Settings.VarType.Boolean,
		L["Debug Mode"],
		Settings.Default.False,
		GetDebugValue,
		SetDebugValue
	)
	Settings.CreateCheckbox(generalCat, debugSetting, L["Toggle debug output"])

	-- Uma subcategoria por módulo (em ordem)
	local orderedMods = {}
	for _, def in pairs(addon.modules) do
		orderedMods[#orderedMods + 1] = def
	end
	table.sort(orderedMods, function(a, b) return (a.order or 100) < (b.order or 100) end)
	for _, def in ipairs(orderedMods) do
		if addon:IsModuleEnabled(def.id) and def.AddSettings then
			local subcat, sublayout = Settings.RegisterVerticalLayoutSubcategory(category, def.name)
			Settings.RegisterAddOnCategory(subcat)
			def:AddSettings(subcat, sublayout)
		end
	end
end
