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

	-- Toggles de módulos
	local orderedMods = {}
	for _, def in pairs(addon.modules) do
		orderedMods[#orderedMods + 1] = def
	end
	table.sort(orderedMods, function(a, b) return (a.order or 100) < (b.order or 100) end)

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Funcionalidades"))
	for _, def in ipairs(orderedMods) do
		local id = def.id
		local function GetEnabled() return addon:IsModuleEnabled(id) end
		local function SetEnabled(value) addon:SetModuleEnabled(id, value) end
		local setting = Settings.RegisterProxySetting(
			category,
			"WoWPersonal_Module_" .. id,
			Settings.VarType.Boolean,
			def.name,
			Settings.Default.True,
			GetEnabled,
			SetEnabled
		)
		Settings.CreateCheckbox(category, setting, "Ativar ou desativar " .. def.name)
	end

	-- Uma subcategoria por módulo (em ordem)
	for _, def in ipairs(orderedMods) do
		if def.AddSettings then
			local subcat, sublayout = Settings.RegisterVerticalLayoutSubcategory(category, def.name)
			Settings.RegisterAddOnCategory(subcat)
			def:AddSettings(subcat, sublayout)
		end
	end
end
