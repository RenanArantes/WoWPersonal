-- Retrieve addon folder name, and our local, private namespace.
---@type string
local addonName = ...
---@class addon
local addon = select(2, ...)

-- Lua API
-----------------------------------------------------------
-- Upvalue any lua functions used here.
local pairs = pairs

-- WoW API
-----------------------------------------------------------
-- Upvalue any WoW functions used here.
local _G = _G
local GetLocale = _G.GetLocale

-- Localization system.
-----------------------------------------------------------
-- Do not modify the function,
-- just the locales in the table below!
---@type table<string, string>
local L = (function(tbl, defaultLocale)
	local gameLocale = GetLocale()                  -- The locale currently used by the game client.
	local L = tbl[gameLocale] or tbl[defaultLocale] -- Get the localization for the current locale, or use your default.
	-- Replace the boolean 'true' with the key,
	-- to simplify locale creation and reduce space needed.
	for i in pairs(L) do
		if (L[i] == true) then
			L[i] = i
		end
	end
	-- If the game client is in another locale than your default,
	-- fill in any missing localization in the client's locale
	-- with entries from your default locale.
	if (gameLocale ~= defaultLocale) then
		for i, msg in pairs(tbl[defaultLocale]) do
			if (not L[i]) then
				-- Replace the boolean 'true' with the key,
				-- to simplify locale creation and reduce space needed.
				L[i] = (msg == true) and i or msg
			end
		end
	end
	return L
end)({
	-- ENTER YOUR LOCALIZATION HERE!
	-----------------------------------------------------------
	-- * Note that you MUST include a full table for your primary/default locale!
	-- * Entries where the value (to the right) is the boolean 'true',
	--   will use the key (to the left) as the value instead!
	["ptBR"] = {
		[addonName] = "WoWPersonal",
		["Visibility Options"] = "Opções de Visibilidade",
		["In City"] = "Na cidade",
		["In PVE Instance"] = "Na instância PVE",
		["In PvP Instance"] = "Na instância PvP",
		["In Open World"] = "No mundo aberto",
		["Transparent"] = "Transparente",
		["Visibility Mode"] = "Modo de Visibilidade",
		["Select when this element should be visible"] = "Selecione quando este elemento deve estar visível",
		["Transparency"] = "Transparência",
		["Control transparency level (0 = invisible, 1 = opaque)"] = "Controla o nível de transparência (0 = invisível, 1 = opaco)",
		["Control transparency level when in combat (0 = invisible, 1 = opaque)"] = "Controla o nível de transparência quando em combate (0 = invisível, 1 = opaco)",
		["Control transparency level when out of combat (0 = invisible, 1 = opaque)"] = "Controla o nível de transparência quando fora de combate (0 = invisível, 1 = opaco)",
		["Current Condition"] = "Condição Atual",
		["Debug Mode"] = "Modo de Depuração",
		["Toggle debug output"] = "Alternar saída de depuração",
		["Show in this scenario"] = "Mostrar neste cenário",
		["Transparency in combat for this scenario"] = "Transparência em combate neste cenário",
		["Transparency out of combat for this scenario"] = "Transparência fora de combate neste cenário",
	},
	["enUS"] = {
		[addonName] = "WoWPersonal",
		["Visibility Options"] = "Visibility Options",
		["In City"] = "In City",
		["In PVE Instance"] = "In PVE Instance",
		["In PvP Instance"] = "In PvP Instance",
		["In Open World"] = "In Open World",
		["Transparent"] = "Transparent",
		["Visibility Mode"] = "Visibility Mode",
		["Select when this element should be visible"] = "Select when this element should be visible",
		["Transparency"] = "Transparency",
		["Control transparency level (0 = invisible, 1 = opaque)"] = "Control transparency level (0 = invisible, 1 = opaque)",
		["Control transparency level when in combat (0 = invisible, 1 = opaque)"] = "Control transparency level when in combat (0 = invisible, 1 = opaque)",
		["Control transparency level when out of combat (0 = invisible, 1 = opaque)"] = "Control transparency level when out of combat (0 = invisible, 1 = opaque)",
		["Current Condition"] = "Current Condition",
		["Debug Mode"] = "Debug Mode",
		["Toggle debug output"] = "Toggle debug output",
		["Show in this scenario"] = "Show in this scenario",
		["Transparency in combat for this scenario"] = "Transparency in combat for this scenario",
		["Transparency out of combat for this scenario"] = "Transparency out of combat for this scenario",
	},
	["esES"] = {},
	["deDE"] = {},
	["frFR"] = {},
	["itIT"] = {},
	["koKR"] = {},
	["ptPT"] = {},
	["ruRU"] = {},
	["zhCN"] = {},
	["zhTW"] = {},

	-- The primary/default locale of your addon.
	-- * You should change this code to your default locale.
	-- * Note that you MUST include a full table for your primary/default locale!
}, "ptBR")

-- Make it available addon-wide
addon.L = L
