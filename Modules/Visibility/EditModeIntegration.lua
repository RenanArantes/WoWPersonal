---@class addon
local addon = select(2, ...)
local L = addon.L

-- Lua API
-----------------------------------------------------------
local pairs = pairs
local ipairs = ipairs
local hooksecurefunc = hooksecurefunc

-- WoW API
-----------------------------------------------------------
local _G = _G
local C_Timer = _G.C_Timer
local C_EditMode = _G.C_EditMode
local Settings = _G.Settings
local CreateFrame = _G.CreateFrame

-- Integração com Edit Mode do WoW
-----------------------------------------------------------

-- Constantes do Edit Mode nativo
local EDIT_MODE_VISIBILITY_OPTIONS = {
	[1] = "always",
	[2] = "combat",
	[3] = "hidden",
}

-- Mapeamento dos valores do Edit Mode para nossos modos
-- (addon.visibilityModes.ALWAYS/COMBAT/HIDDEN não existem — referências intencionalmente nil)
local editModeToOurMode = {
	always = addon.visibilityModes and addon.visibilityModes.ALWAYS,
	combat = addon.visibilityModes and addon.visibilityModes.COMBAT,
	hidden = addon.visibilityModes and addon.visibilityModes.HIDDEN,
}

local ourModeToEditMode = {}
for editMode, ourMode in pairs(editModeToOurMode) do
	if ourMode then ourModeToEditMode[ourMode] = editMode end
end

--- Expande as opções de visibilidade do Edit Mode
function addon:ExpandEditModeVisibilityOptions()
	if self.db and self.db.debugMode then
		self:Debug("Expandindo opções de visibilidade do Edit Mode...")
	end
	self:HookEditModeVisibilityDropdown()
	self:HookVisibilityApplication()
end

--- Faz hook no dropdown de visibilidade do Edit Mode
function addon:HookEditModeVisibilityDropdown()
	C_Timer.After(1, function()
		local editModeManager = _G["EditModeManagerFrame"]
		if not editModeManager then
			C_Timer.After(1, function()
				self:HookEditModeVisibilityDropdown()
			end)
			return
		end
		self:FindAndHookVisibilityDropdowns()
	end)
end

--- Encontra e faz hook nos dropdowns de visibilidade
function addon:FindAndHookVisibilityDropdowns()
	if Settings and Settings.CreateDropdown then
		hooksecurefunc(Settings, "CreateDropdown", function(category, setting, options, tooltip)
			if setting and setting:GetName() then
				local settingName = setting:GetName()
				if settingName:lower():match("visibility") or
				   (tooltip and tooltip:lower():match("visibilidade")) or
				   (tooltip and tooltip:lower():match("visibility")) then
					if self.db and self.db.debugMode then
						self:Debug("Dropdown de visibilidade encontrado:", settingName)
					end
					if options then
						self:ExpandDropdownOptions(options)
					end
				end
			end
		end)
	end
end

--- Expande as opções de um dropdown com novos modos de visibilidade
---@param options table
function addon:ExpandDropdownOptions(options)
	if not options or not options.AddOption then return end

	local newOptions = {
		{ value = addon.visibilityModes and addon.visibilityModes.CITY,         text = L["In City"] },
		{ value = addon.visibilityModes and addon.visibilityModes.INSTANCE_PVE, text = L["In PVE Instance"] },
		{ value = addon.visibilityModes and addon.visibilityModes.INSTANCE_PVP, text = L["In PvP Instance"] },
		{ value = addon.visibilityModes and addon.visibilityModes.OPEN_WORLD,   text = L["In Open World"] },
	}

	for _, option in ipairs(newOptions) do
		if option.value then
			options:AddOption(option.value, option.text)
		end
	end

	if self.db and self.db.debugMode then
		self:Debug("Opções expandidas no dropdown de visibilidade")
	end
end

--- Faz hook na aplicação de visibilidade do Edit Mode
function addon:HookVisibilityApplication()
	if C_EditMode and C_EditMode.ApplyAccountSettings then
		hooksecurefunc(C_EditMode, "ApplyAccountSettings", function()
			self:ApplyCustomVisibilityModes()
		end)
	end
end

--- Aplica modos de visibilidade customizados a elementos do Edit Mode
function addon:ApplyCustomVisibilityModes()
	if not (C_EditMode and C_EditMode.GetAccountSettings) then return end
	local settings = C_EditMode.GetAccountSettings()
	if not settings or type(settings) ~= "table" then return end
	local accounts = settings.accounts or settings
	if type(accounts) ~= "table" then return end
	for _, accountSettings in pairs(accounts) do
		if type(accountSettings) == "table" and accountSettings.layouts then
			for _, layout in pairs(accountSettings.layouts) do
				if type(layout) == "table" and layout.elements then
					for _, element in pairs(layout.elements) do
						if type(element) == "table" and element.visibilitySetting then
							self:ApplyEditModeVisibility(element, element.visibilitySetting)
						end
					end
				end
			end
		end
	end
end

--- Aplica a lógica de visibilidade baseada no modo selecionado num elemento do Edit Mode
---@param elementInfo table
---@param visibilityMode string
function addon:ApplyEditModeVisibility(elementInfo, visibilityMode)
	if not editModeToOurMode[visibilityMode] then return end
	local shouldShow = self:CheckVisibilityCondition(visibilityMode)
	if elementInfo and elementInfo.frame then
		if shouldShow then
			elementInfo.frame:Show()
		else
			elementInfo.frame:Hide()
		end
	end
end

--- Monitora a criação de dropdowns e expande os de visibilidade
function addon:MonitorDropdownCreation()
	local monitorFrame = CreateFrame("Frame")
	monitorFrame:RegisterEvent("ADDON_LOADED")
	monitorFrame:RegisterEvent("VARIABLES_LOADED")
	monitorFrame:SetScript("OnEvent", function(_, event)
		if event == "ADDON_LOADED" or event == "VARIABLES_LOADED" then
			C_Timer.After(0.5, function()
				addon:ExpandEditModeVisibilityOptions()
			end)
		end
	end)
	if Settings then
		C_Timer.After(1, function()
			addon:ExpandEditModeVisibilityOptions()
		end)
	end
end
