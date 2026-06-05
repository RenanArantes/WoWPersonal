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
		["Evoker"] = "Conjurante (Evoker)",
		["Disintegrate Chaining"] = "Chaining do Desintegrar",
		["Show Disintegrate tick markers"] = "Mostrar marcadores de tick do Desintegrar",
		["Show Disintegrate tick markers tooltip"] = "Desenha linhas verticais na barra de canalização nos momentos de cada tick. A barra de canal esvazia da direita para a esquerda: tick 1 ocorre no início (direita), o último tick acontece no fim (esquerda). Azure Celerity é detectado automaticamente (5 ticks em vez de 4).",
		["Show clip cost gradient"] = "Mostrar gradiente de custo de clip",
		["Show clip cost gradient tooltip"] = "Pinta cada segmento da barra conforme o custo de clipar ali: verde (chain limpo entre penúltimo e último tick), amarelo (clip pequeno), vermelho (clip pesado).",
		["Warn on Mass Disintegrate chain"] = "Avisar ao chainar Mass Disintegrate",
		["Warn on Mass Disintegrate chain tooltip"] = "Como Scalecommander, chainar Mass Disintegrate em Disintegrate normal causa perda de % do buff. Quando ativo, suprime a zona verde e mostra aviso visual durante Mass Disintegrate.",
		["Chain overlay opacity"] = "Opacidade do overlay de chain",
		["Chain overlay opacity tooltip"] = "Controla a opacidade da zona verde (chain limpo) e do gradiente de clip cost.",
		["Keybinds"] = "Atalhos de teclado",
		["Essential Cooldown Viewer"] = "Visualizador de Cooldowns Essenciais",
		["Utility Cooldown Viewer"] = "Visualizador de Cooldowns Utilitários",
		["Show keybinds"] = "Mostrar atalhos",
		["Show keybinds tooltip"] = "Mostra o atalho da barra de ação no canto de cada ícone deste visualizador.",
		["Anchor"] = "Ancoragem",
		["Anchor tooltip"] = "Canto do ícone onde o texto do atalho é posicionado.",
		["Font size"] = "Tamanho da fonte",
		["Font size tooltip"] = "Tamanho da fonte do texto do atalho.",
		["Horizontal offset"] = "Deslocamento horizontal",
		["Horizontal offset tooltip"] = "Ajuste horizontal da posição do texto do atalho (pixels).",
		["Vertical offset"] = "Deslocamento vertical",
		["Vertical offset tooltip"] = "Ajuste vertical da posição do texto do atalho (pixels).",
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
		["Evoker"] = "Evoker",
		["Disintegrate Chaining"] = "Disintegrate Chaining",
		["Show Disintegrate tick markers"] = "Show Disintegrate tick markers",
		["Show Disintegrate tick markers tooltip"] = "Draws vertical lines on the cast bar at each tick. The channel bar drains right to left: tick 1 happens at the start (right), the final tick happens at the end (left). Azure Celerity is detected automatically (5 ticks instead of 4).",
		["Show clip cost gradient"] = "Show clip cost gradient",
		["Show clip cost gradient tooltip"] = "Colors each segment by the cost of clipping there: green (clean chain between penultimate and final tick), yellow (small clip), red (heavy clip).",
		["Warn on Mass Disintegrate chain"] = "Warn on Mass Disintegrate chain",
		["Warn on Mass Disintegrate chain tooltip"] = "As Scalecommander, chaining Mass Disintegrate into normal Disintegrate loses % of the buff. When enabled, the green chain zone is suppressed and a visual warning is shown during Mass Disintegrate.",
		["Chain overlay opacity"] = "Chain overlay opacity",
		["Chain overlay opacity tooltip"] = "Controls the opacity of the green chain zone and the clip cost gradient.",
		["Keybinds"] = "Keybinds",
		["Essential Cooldown Viewer"] = "Essential Cooldown Viewer",
		["Utility Cooldown Viewer"] = "Utility Cooldown Viewer",
		["Show keybinds"] = "Show keybinds",
		["Show keybinds tooltip"] = "Shows the action bar keybind in the corner of each icon in this viewer.",
		["Anchor"] = "Anchor",
		["Anchor tooltip"] = "Corner of the icon where the keybind text is positioned.",
		["Font size"] = "Font size",
		["Font size tooltip"] = "Font size of the keybind text.",
		["Horizontal offset"] = "Horizontal offset",
		["Horizontal offset tooltip"] = "Horizontal adjustment of the keybind text position (pixels).",
		["Vertical offset"] = "Vertical offset",
		["Vertical offset tooltip"] = "Vertical adjustment of the keybind text position (pixels).",
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
