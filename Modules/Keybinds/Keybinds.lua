---@class addon
local addon = select(2, ...)
local L = addon.L

-- Lua API
-----------------------------------------------------------
local pairs = pairs
local ipairs = ipairs

-- WoW API
-----------------------------------------------------------
local _G = _G
local CreateFrame = _G.CreateFrame
local C_Timer = _G.C_Timer
local C_Spell = _G.C_Spell
local C_Item = _G.C_Item
local C_CooldownViewer = _G.C_CooldownViewer
local GetBindingKey = _G.GetBindingKey
local GetBindingText = _G.GetBindingText
local GetActionInfo = _G.GetActionInfo
local GetActionText = _G.GetActionText
local GetMacroSpell = _G.GetMacroSpell
local hooksecurefunc = _G.hooksecurefunc

-- Module state
-----------------------------------------------------------
local Keybinds = {}

local DEBUG = false
local function PrintDebug(...)
	if DEBUG then
		print("|cff33ff99WoWPersonal Keybinds:|r", ...)
	end
end

local isModuleEnabled = false
local areHooksInitialized = false
local spellIDToKeyBindCache = {}

-- Apenas as barras de ação padrão da Blizzard são suportadas.
local SpellIDOverrides = {}

-- Viewers suportados → nome da configuração (sufixo das chaves do DB)
local viewersSettingKey = {
	EssentialCooldownViewer = "Essential",
	UtilityCooldownViewer = "Utility",
}

local DEFAULT_FONT_PATH = "Fonts\\FRIZQT__.TTF"

local function GetFontPath()
	return DEFAULT_FONT_PATH
end

-- Settings / DB helpers
-----------------------------------------------------------
local function IsKeybindEnabledForViewer(viewerSettingName)
	if not addon.db then
		return false
	end
	return addon.db["keybindShow_" .. viewerSettingName] == true
end

local function IsKeybindEnabledForAnyViewer()
	if not addon.db then
		return false
	end
	for _, viewerSettingName in pairs(viewersSettingKey) do
		if addon.db["keybindShow_" .. viewerSettingName] then
			return true
		end
	end
	return false
end

local function GetKeybindSettings(viewerSettingName)
	local defaults = {
		anchor = "TOPRIGHT",
		fontSize = 14,
		offsetX = -3,
		offsetY = -3,
	}
	if not addon.db then
		return defaults
	end
	return {
		anchor = addon.db["keybindAnchor_" .. viewerSettingName] or defaults.anchor,
		fontSize = addon.db["keybindFontSize_" .. viewerSettingName] or defaults.fontSize,
		offsetX = addon.db["keybindOffsetX_" .. viewerSettingName] or defaults.offsetX,
		offsetY = addon.db["keybindOffsetY_" .. viewerSettingName] or defaults.offsetY,
	}
end

-- Keybind formatting
-----------------------------------------------------------
local function GetFormattedKeybind(key)
	if not key or key == "" then
		return ""
	end

	local bindingText = GetBindingText and GetBindingText(key, "KEY_", true)
	local displayKey = (bindingText and bindingText ~= "") and bindingText or key
	if displayKey:find("|", 1, true) then
		return displayKey
	end

	local upperKey = key:upper()

	upperKey = upperKey:gsub("PADLTRIGGER", "LT")
	upperKey = upperKey:gsub("PADRTRIGGER", "RT")
	upperKey = upperKey:gsub("PADLSHOULDER", "LB")
	upperKey = upperKey:gsub("PADRSHOULDER", "RB")
	upperKey = upperKey:gsub("PADLSTICK", "LS")
	upperKey = upperKey:gsub("PADRSTICK", "RS")
	upperKey = upperKey:gsub("PADDPADUP", "D↑")
	upperKey = upperKey:gsub("PADDPADDOWN", "D↓")
	upperKey = upperKey:gsub("PADDPADLEFT", "D←")
	upperKey = upperKey:gsub("PADDPADRIGHT", "D→")
	upperKey = upperKey:gsub("^PAD", "")

	upperKey = upperKey:gsub("SHIFT%-", "S")
	upperKey = upperKey:gsub("META%-", "M")
	upperKey = upperKey:gsub("CTRL%-", "C")
	upperKey = upperKey:gsub("ALT%-", "A")
	upperKey = upperKey:gsub("STRG%-", "ST") -- German Ctrl

	upperKey = upperKey:gsub("MOUSE%s?WHEEL%s?UP", "MWU")
	upperKey = upperKey:gsub("MOUSE%s?WHEEL%s?DOWN", "MWD")
	upperKey = upperKey:gsub("MIDDLE%s?MOUSE", "MM")
	upperKey = upperKey:gsub("MOUSE%s?BUTTON%s?", "M")
	upperKey = upperKey:gsub("BUTTON", "M")

	upperKey = upperKey:gsub("NUMPAD%s?PLUS", "N+")
	upperKey = upperKey:gsub("NUMPAD%s?MINUS", "N-")
	upperKey = upperKey:gsub("NUMPAD%s?MULTIPLY", "N*")
	upperKey = upperKey:gsub("NUMPAD%s?DIVIDE", "N/")
	upperKey = upperKey:gsub("NUMPAD%s?DECIMAL", "N.")
	upperKey = upperKey:gsub("NUMPAD%s?ENTER", "NEnt")
	upperKey = upperKey:gsub("NUMPAD%s?", "N")
	upperKey = upperKey:gsub("NUM%s?", "N")
	upperKey = upperKey:gsub("NPAD%s?", "N")

	upperKey = upperKey:gsub("PAGE%s?UP", "PGU")
	upperKey = upperKey:gsub("PAGE%s?DOWN", "PGD")
	upperKey = upperKey:gsub("INSERT", "INS")
	upperKey = upperKey:gsub("DELETE", "DEL")
	upperKey = upperKey:gsub("SPACEBAR", "Spc")
	upperKey = upperKey:gsub("ENTER", "Ent")
	upperKey = upperKey:gsub("ESCAPE", "Esc")
	upperKey = upperKey:gsub("TAB", "Tab")
	upperKey = upperKey:gsub("CAPS%s?LOCK", "Caps")
	upperKey = upperKey:gsub("HOME", "Hom")
	upperKey = upperKey:gsub("END", "End")

	return upperKey
end

-- Apenas barras padrão da Blizzard
local ButtonRowsPrefix = {
	["blizzard"] = {
		[1] = "ActionButton",
		[2] = "MultiBarBottomLeftButton",
		[3] = "MultiBarBottomRightButton",
		[4] = "MultiBarRightButton",
		[5] = "MultiBarLeftButton",
		[6] = "MultiBar5Button",
		[7] = "MultiBar6Button",
		[8] = "MultiBar7Button",
	},
}

function Keybinds:GetActionsTableBySpellId()
	PrintDebug("Building Actions Table By Spell ID")

	local spellIdToKeyBind = {}

	local function assignResultForSlot(slot, keyBind)
		local actionType, id, subType = GetActionInfo(slot)
		if not spellIdToKeyBind[id] then
			if (actionType == "macro" and subType == "spell") or (actionType == "spell") then
				spellIdToKeyBind[id] = keyBind
				if SpellIDOverrides[id] and not spellIdToKeyBind[SpellIDOverrides[id]] then
					spellIdToKeyBind[SpellIDOverrides[id]] = keyBind
				end
			elseif actionType == "macro" then
				local macroName = GetActionText(slot)
				local macroSpellID = GetMacroSpell(macroName)

				if macroSpellID and not spellIdToKeyBind[macroSpellID] then
					spellIdToKeyBind[macroSpellID] = keyBind
					if
						SpellIDOverrides[macroSpellID] and not spellIdToKeyBind[SpellIDOverrides[macroSpellID]]
					then
						spellIdToKeyBind[SpellIDOverrides[macroSpellID]] = keyBind
					end
				end
			elseif actionType == "item" then
				local _spellName, spellId = C_Item.GetItemSpell(id)
				if spellId and not spellIdToKeyBind[spellId] then
					spellIdToKeyBind[spellId] = keyBind
				end
			end
		end
	end

	for i = 1, 8 do
		local bar = ButtonRowsPrefix["blizzard"][i]

		if bar then
			for j = 1, 12 do
				local buttonName = bar .. j
				local button = _G[buttonName]
				local slot = button and button.action
				local keyBoundTarget = button and button.commandName
				if button and slot and keyBoundTarget then
					local keyBind = GetBindingKey(keyBoundTarget)
					if keyBind then
						assignResultForSlot(slot, keyBind)
					end
				end
			end
		end
	end
	return spellIdToKeyBind
end

local function BuildSpellKeyBindMapping()
	local spellIDToKeyBind = Keybinds:GetActionsTableBySpellId()

	local spellIDToKeyBindFormatted = {}

	for spellID, rawKey in pairs(spellIDToKeyBind) do
		if rawKey and rawKey ~= "" and rawKey ~= "●" and not spellIDToKeyBindFormatted[spellID] then
			local formattedKey = GetFormattedKeybind(rawKey)
			if formattedKey ~= "" then
				spellIDToKeyBindFormatted[spellID] = formattedKey
			end
		end
	end
	for spellID, keyBind in pairs(spellIDToKeyBindCache) do
		if not spellIDToKeyBindFormatted[spellID] then
			spellIDToKeyBindFormatted[spellID] = keyBind
		end
	end
	spellIDToKeyBindCache = spellIDToKeyBindFormatted
	return spellIDToKeyBindFormatted
end

function Keybinds:FindKeyBindForSpell(spellID, spellToKeybind)
	if not spellID or spellID == 0 then
		return ""
	end

	-- Direct match
	if spellToKeybind[spellID] then
		return spellToKeybind[spellID]
	end

	-- Try override spell
	local overrideSpellID = C_Spell.GetOverrideSpell(spellID)
	if overrideSpellID and spellToKeybind[overrideSpellID] then
		return spellToKeybind[overrideSpellID]
	end

	-- Try base spell
	local baseSpellID = C_Spell.GetBaseSpell(spellID)
	if baseSpellID and spellToKeybind[baseSpellID] then
		return spellToKeybind[baseSpellID]
	end

	return ""
end

local function GetOrCreateKeybindText(icon, viewerSettingName)
	if icon.wowpKeybindText and icon.wowpKeybindText.text then
		return icon.wowpKeybindText.text
	end

	local settings = GetKeybindSettings(viewerSettingName)
	icon.wowpKeybindText = CreateFrame("Frame", nil, icon, "BackdropTemplate")
	icon.wowpKeybindText:SetFrameLevel(icon:GetFrameLevel() + 4)
	local keybindText = icon.wowpKeybindText:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	keybindText:SetPoint(settings.anchor, icon, settings.anchor, settings.offsetX, settings.offsetY)
	keybindText:SetTextColor(1, 1, 1, 1)
	keybindText:SetShadowColor(0, 0, 0, 1)
	keybindText:SetShadowOffset(1, -1)
	keybindText:SetDrawLayer("OVERLAY", 7)

	icon.wowpKeybindText.text = keybindText
	return icon.wowpKeybindText.text
end

local function ApplyKeybindTextSettings(icon, viewerSettingName)
	if not icon.wowpKeybindText then
		return
	end

	local settings = GetKeybindSettings(viewerSettingName)
	local keybindText = GetOrCreateKeybindText(icon, viewerSettingName)

	icon.wowpKeybindText:Show()
	keybindText:ClearAllPoints()
	keybindText:SetPoint(settings.anchor, icon, settings.anchor, settings.offsetX, settings.offsetY)
	keybindText:SetFont(GetFontPath(), settings.fontSize, "OUTLINE")
end

local function ExtractSpellIDFromChild(child)
	if child.cooldownID then
		local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(child.cooldownID)
		if info then
			return info.spellID
		end
	end
	if child.spellID then
		return child.spellID
	end
	return nil
end

local function UpdateIconKeybind(icon, viewerSettingName, keybind)
	if not icon then
		return
	end

	if not IsKeybindEnabledForViewer(viewerSettingName) then
		if icon.wowpKeybindText then
			icon.wowpKeybindText:Hide()
		end
		return
	end

	local keybindText = GetOrCreateKeybindText(icon, viewerSettingName)
	icon.wowpKeybindText:Show()
	keybindText:SetText(keybind)
	keybindText:Show()
	if not keybind or keybind == "" then
		if icon.wowpKeybindText then
			icon.wowpKeybindText:Hide()
		end
	end
end

local function UpdateViewerKeybinds(viewerName)
	local viewerFrame = _G[viewerName]
	if not viewerFrame then
		return
	end

	local settingName = viewersSettingKey[viewerName]
	if not settingName then
		return
	end

	PrintDebug("UpdateViewerKeybinds for", viewerName)

	local spellToKeybind = BuildSpellKeyBindMapping()

	local children = { viewerFrame:GetChildren() }
	for _, child in ipairs(children) do
		if child.Icon then
			local spellID = ExtractSpellIDFromChild(child)
			local keybind = ""

			if spellID then
				keybind = Keybinds:FindKeyBindForSpell(spellID, spellToKeybind)
			end

			UpdateIconKeybind(child, settingName, keybind)
		end
	end
end

function Keybinds:UpdateViewerKeybinds(viewerName)
	UpdateViewerKeybinds(viewerName)
end

function Keybinds:UpdateAllKeybinds()
	for viewerName, _ in pairs(viewersSettingKey) do
		UpdateViewerKeybinds(viewerName)
		self:ApplyKeybindSettings(viewerName)
	end
end

function Keybinds:ApplyKeybindSettings(viewerName)
	local viewerFrame = _G[viewerName]
	if not viewerFrame then
		return
	end

	local settingName = viewersSettingKey[viewerName]
	if not settingName then
		return
	end

	local children = { viewerFrame:GetChildren() }
	for _, child in ipairs(children) do
		if child.wowpKeybindText then
			ApplyKeybindTextSettings(child, settingName)
		end
	end
end

-- Lifecycle
-----------------------------------------------------------
local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function(_, event)
	if not isModuleEnabled then
		return
	end

	PrintDebug("Event:", event)
	if
		event == "PLAYER_SPECIALIZATION_CHANGED"
		or event == "UPDATE_BINDINGS"
		or event == "ACTIONBAR_HIDEGRID"
		or event == "UPDATE_BONUS_ACTIONBAR"
	then
		spellIDToKeyBindCache = {}
	end

	C_Timer.After(0.1, function()
		Keybinds:UpdateAllKeybinds()
	end)
end)

function Keybinds:Enable()
	if isModuleEnabled then
		return
	end
	PrintDebug("Enabling module")

	isModuleEnabled = true

	eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventFrame:RegisterEvent("UPDATE_BINDINGS")
	eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
	eventFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
	eventFrame:RegisterEvent("ACTIONBAR_HIDEGRID")
	eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
	eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
	eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")

	-- Hook na atualização de layout de cada viewer para reaplicar os keybinds
	if not areHooksInitialized then
		areHooksInitialized = true

		for viewerName, _ in pairs(viewersSettingKey) do
			local viewerFrame = _G[viewerName]
			if viewerFrame and viewerFrame.RefreshLayout then
				hooksecurefunc(viewerFrame, "RefreshLayout", function()
					if not isModuleEnabled then
						return
					end
					PrintDebug("RefreshLayout called for viewer:", viewerName)
					UpdateViewerKeybinds(viewerName)
				end)
			end
		end
	end

	self:UpdateAllKeybinds()
end

function Keybinds:Disable()
	if not isModuleEnabled then
		return
	end
	PrintDebug("Disabling module")

	isModuleEnabled = false
	eventFrame:UnregisterAllEvents()

	for viewerName, _ in pairs(viewersSettingKey) do
		local viewerFrame = _G[viewerName]
		if viewerFrame then
			local children = { viewerFrame:GetChildren() }
			for _, child in ipairs(children) do
				if child.wowpKeybindText then
					child.wowpKeybindText:Hide()
				end
			end
		end
	end
end

--- Reage à mudança de configuração de um viewer (toggle / re-aplicar).
---@param viewerSettingName string  "Essential" ou "Utility"
function Keybinds:OnSettingChanged(viewerSettingName)
	local shouldBeEnabled = IsKeybindEnabledForAnyViewer()

	if shouldBeEnabled and not isModuleEnabled then
		self:Enable()
	elseif not shouldBeEnabled and isModuleEnabled then
		self:Disable()
	elseif isModuleEnabled then
		if viewerSettingName then
			for viewerName, settingName in pairs(viewersSettingKey) do
				if settingName == viewerSettingName then
					UpdateViewerKeybinds(viewerName)
					self:ApplyKeybindSettings(viewerName)
					return
				end
			end
		end
		self:UpdateAllKeybinds()
	end
end

-- Registro do módulo
-----------------------------------------------------------
addon:RegisterModule({
	id             = "keybinds",
	name           = L["Keybinds"] or "Keybinds",
	defaultEnabled = true,
	order          = 15,

	OnEnable = function(_)
		Keybinds:Enable()
	end,

	OnDisable = function(_)
		Keybinds:Disable()
	end,

	AddSettings = function(_, category, layout)
		local Settings = _G["Settings"]
		if not Settings then return end

		-- Ordem das âncoras oferecidas no dropdown
		local anchorOptions = {
			"TOPLEFT", "TOP", "TOPRIGHT",
			"LEFT", "CENTER", "RIGHT",
			"BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT",
		}

		-- (label de seção, sufixo da chave, frame do viewer)
		local viewerSections = {
			{ label = L["Essential Cooldown Viewer"], key = "Essential", frame = "EssentialCooldownViewer" },
			{ label = L["Utility Cooldown Viewer"],   key = "Utility",   frame = "UtilityCooldownViewer" },
		}

		for _, v in ipairs(viewerSections) do
			local viewerKey   = v.key
			local viewerFrame = v.frame

			layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(v.label))

			-- Checkbox: mostrar keybinds
			local showKey = "keybindShow_" .. viewerKey
			local showSetting = Settings.RegisterProxySetting(
				category,
				"WoWPersonal_Keybind_Show_" .. viewerKey,
				Settings.VarType.Boolean,
				L["Show keybinds"],
				Settings.Default.True,
				function() return addon.db and addon.db[showKey] or false end,
				function(value)
					if addon.db then addon.db[showKey] = value end
					Keybinds:OnSettingChanged(viewerKey)
				end
			)
			Settings.CreateCheckbox(category, showSetting, L["Show keybinds tooltip"])

			-- Dropdown: âncora
			local anchorKey = "keybindAnchor_" .. viewerKey
			local anchorSetting = Settings.RegisterProxySetting(
				category,
				"WoWPersonal_Keybind_Anchor_" .. viewerKey,
				Settings.VarType.String,
				L["Anchor"],
				"TOPRIGHT",
				function() return addon.db and addon.db[anchorKey] or "TOPRIGHT" end,
				function(value)
					if addon.db then addon.db[anchorKey] = value end
					Keybinds:ApplyKeybindSettings(viewerFrame)
				end
			)
			local function GetAnchorOptions()
				local container = Settings.CreateControlTextContainer()
				for _, anchor in ipairs(anchorOptions) do
					container:Add(anchor, anchor)
				end
				return container:GetData()
			end
			Settings.CreateDropdown(category, anchorSetting, GetAnchorOptions, L["Anchor tooltip"])

			-- Slider: tamanho da fonte
			local fontSizeKey = "keybindFontSize_" .. viewerKey
			local fontSizeSetting = Settings.RegisterProxySetting(
				category,
				"WoWPersonal_Keybind_FontSize_" .. viewerKey,
				Settings.VarType.Number,
				L["Font size"],
				14,
				function()
					local val = addon.db and addon.db[fontSizeKey]
					return (type(val) == "number") and val or 14
				end,
				function(value)
					if addon.db then addon.db[fontSizeKey] = value end
					Keybinds:ApplyKeybindSettings(viewerFrame)
				end
			)
			local fontSizeOptions = Settings.CreateSliderOptions(8, 24, 1)
			fontSizeOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(val)
				return string.format("%d", val)
			end)
			Settings.CreateSlider(category, fontSizeSetting, fontSizeOptions, L["Font size tooltip"])

			-- Slider: offset horizontal
			local offsetXKey = "keybindOffsetX_" .. viewerKey
			local offsetXSetting = Settings.RegisterProxySetting(
				category,
				"WoWPersonal_Keybind_OffsetX_" .. viewerKey,
				Settings.VarType.Number,
				L["Horizontal offset"],
				-3,
				function()
					local val = addon.db and addon.db[offsetXKey]
					return (type(val) == "number") and val or -3
				end,
				function(value)
					if addon.db then addon.db[offsetXKey] = value end
					Keybinds:ApplyKeybindSettings(viewerFrame)
				end
			)
			local offsetXOptions = Settings.CreateSliderOptions(-40, 40, 1)
			offsetXOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(val)
				return string.format("%d", val)
			end)
			Settings.CreateSlider(category, offsetXSetting, offsetXOptions, L["Horizontal offset tooltip"])

			-- Slider: offset vertical
			local offsetYKey = "keybindOffsetY_" .. viewerKey
			local offsetYSetting = Settings.RegisterProxySetting(
				category,
				"WoWPersonal_Keybind_OffsetY_" .. viewerKey,
				Settings.VarType.Number,
				L["Vertical offset"],
				-3,
				function()
					local val = addon.db and addon.db[offsetYKey]
					return (type(val) == "number") and val or -3
				end,
				function(value)
					if addon.db then addon.db[offsetYKey] = value end
					Keybinds:ApplyKeybindSettings(viewerFrame)
				end
			)
			local offsetYOptions = Settings.CreateSliderOptions(-40, 40, 1)
			offsetYOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(val)
				return string.format("%d", val)
			end)
			Settings.CreateSlider(category, offsetYSetting, offsetYOptions, L["Vertical offset tooltip"])
		end
	end,
})
