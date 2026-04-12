---@class addon
local addon = select(2, ...)
local L = addon.L

-- Lua API
-----------------------------------------------------------
local ipairs = ipairs
local pairs = pairs
local select = select

-- WoW API
-----------------------------------------------------------
local _G = _G
local IsResting = _G.IsResting
local IsInInstance = _G.IsInInstance
local UnitAffectingCombat = _G.UnitAffectingCombat
local C_Timer = _G.C_Timer

-- Constants
-----------------------------------------------------------
addon.visibilityModes = {
	CITY = "city",
	INSTANCE_PVE = "instance_pve",
	INSTANCE_PVP = "instance_pvp",
	OPEN_WORLD = "open_world",
}

addon.visibilityModeNames = {
	[addon.visibilityModes.CITY] = L["In City"],
	[addon.visibilityModes.INSTANCE_PVE] = L["In PVE Instance"],
	[addon.visibilityModes.INSTANCE_PVP] = L["In PvP Instance"],
	[addon.visibilityModes.OPEN_WORLD] = L["In Open World"],
}

-- Estado atual do jogador
addon.currentState = {
	inCombat = false,
	inCity = false,
	inInstancePVE = false,
	inInstancePVP = false,
	inOpenWorld = false,
	instanceType = nil,
}

-- Frames registrados para controle de visibilidade
addon.registeredFrames = {}

-- Timer e flag para opacidade total pós-combate
addon.outOfCombatFadeTimer = nil
addon.fullOpacityOverride = false

-- Detecção de estado
-----------------------------------------------------------

--- Verifica se o jogador está em uma cidade (área de descanso)
---@return boolean
function addon:IsInCity()
	return IsResting() == true
end

--- Verifica o tipo de instância atual
---@return string|nil instanceType, boolean isInInstance, boolean isPVE, boolean isPVP
function addon:GetInstanceType()
	local inInstance, instanceType = IsInInstance()
	if not inInstance then
		return nil, false, false, false
	end
	local isPVE = (instanceType == "party") or (instanceType == "raid") or (instanceType == "scenario")
	local isPVP = (instanceType == "arena") or (instanceType == "pvp") or (instanceType == "ratedbg")
	return instanceType, true, isPVE, isPVP
end

--- Atualiza o estado atual do jogador e dispara atualização de frames se mudou
function addon:UpdateCurrentState()
	local oldState = {}
	for k, v in pairs(self.currentState) do
		oldState[k] = v
	end

	self.currentState.inCombat = UnitAffectingCombat("player") == true
	self.currentState.inCity = self:IsInCity()

	local instanceType, inInstance, isPVE, isPVP = self:GetInstanceType()
	self.currentState.instanceType = instanceType
	self.currentState.inInstancePVE = isPVE
	self.currentState.inInstancePVP = isPVP
	self.currentState.inOpenWorld = not self.currentState.inCity and not inInstance

	local stateChanged = false
	for k, v in pairs(self.currentState) do
		if oldState[k] ~= v then
			stateChanged = true
			break
		end
	end

	if stateChanged then
		self:UpdateAllFrameVisibility()
	end
end

--- Retorna o cenário atual: "city" | "instance_pve" | "instance_pvp" | "open_world"
---@return string
function addon:GetCurrentScenario()
	if self.currentState.inCity then
		return self.visibilityModes.CITY
	elseif self.currentState.inInstancePVE then
		return self.visibilityModes.INSTANCE_PVE
	elseif self.currentState.inInstancePVP then
		return self.visibilityModes.INSTANCE_PVP
	elseif self.currentState.inOpenWorld then
		return self.visibilityModes.OPEN_WORLD
	end
	return self.visibilityModes.OPEN_WORLD
end

--- Retorna a config do cenário (enabled + transparências), com defaults
---@param scenarioKey string
---@return table
function addon:GetScenarioConfig(scenarioKey)
	local scenarios = self.db and self.db.scenarios
	if type(scenarios) ~= "table" or type(scenarios[scenarioKey]) ~= "table" then
		return { enabled = true, transparencyInCombat = 1.0, transparencyOutOfCombat = 1.0 }
	end
	local s = scenarios[scenarioKey]
	return {
		enabled = s.enabled ~= false,
		transparencyInCombat = s.transparencyInCombat or 1.0,
		transparencyOutOfCombat = s.transparencyOutOfCombat or 1.0,
	}
end

--- Cancela o timer de fade pós-combate e remove o override de opacidade total
function addon:CancelOutOfCombatFade()
	if self.outOfCombatFadeTimer then
		---@diagnostic disable-next-line: undefined-field
		self.outOfCombatFadeTimer:Cancel()
		self.outOfCombatFadeTimer = nil
	end
	self.fullOpacityOverride = false
end

--- Ativa o override de opacidade total e atualiza todos os frames
function addon:ApplyFullOpacityOverride()
	self.fullOpacityOverride = true
	self:UpdateAllFrameVisibility()
end

--- Agenda a transição para opacidade total após N segundos fora de combate
function addon:ScheduleOutOfCombatFade()
	self:CancelOutOfCombatFade()
	local db = self.db
	if not db or not db.outOfCombatFadeEnabled then return end
	local delay = db.outOfCombatFadeDelay or 3
	if delay <= 0 then
		self:ApplyFullOpacityOverride()
		return
	end
	self.outOfCombatFadeTimer = C_Timer.After(delay, function()
		self.outOfCombatFadeTimer = nil
		addon:ApplyFullOpacityOverride()
	end)
end

--- Atualiza a visibilidade de um frame específico baseado no cenário atual
---@param frameName string
---@param frame Frame|nil
function addon:UpdateFrameVisibility(frameName, frame)
	if not frame then
		frame = _G[frameName]
	end

	if not frame then
		if self.db and self.db.debugMode then
			self:Debug("Frame não encontrado:", frameName)
		end
		return
	end

	local scenario = self:GetCurrentScenario()
	local config = self:GetScenarioConfig(scenario)

	if config.enabled then
		local inCombat = self.currentState.inCombat
		local transparency
		if self.fullOpacityOverride and not inCombat then
			transparency = 0.0
		else
			transparency = inCombat and config.transparencyInCombat or config.transparencyOutOfCombat
		end
		frame:SetAlpha(transparency)
		frame:Show()
		if self.db and self.db.debugMode then
			self:Debug(string.format("Frame %s: visível (cenário: %s, transparência: %.2f)", frameName, scenario, transparency))
		end
	else
		frame:Hide()
		if self.db and self.db.debugMode then
			self:Debug(string.format("Frame %s: oculto (cenário: %s)", frameName, scenario))
		end
	end
end

--- Atualiza a visibilidade de todos os frames registrados
function addon:UpdateAllFrameVisibility()
	for frameName, frame in pairs(self.registeredFrames) do
		self:UpdateFrameVisibility(frameName, frame)
	end
end

--- Registra um frame para controle de visibilidade e persiste o nome no DB
---@param frameName string
---@param frame Frame|nil
---@return boolean
function addon:RegisterFrame(frameName, frame)
	if not frame then
		frame = _G[frameName]
	end

	if not frame then
		self:Print("Erro: Frame não encontrado:", frameName)
		return false
	end

	self.registeredFrames[frameName] = frame
	if self.db then
		if type(self.db.registeredFrames) ~= "table" then
			self.db.registeredFrames = {}
		end
		local found
		for _, name in ipairs(self.db.registeredFrames) do
			if name == frameName then found = true; break end
		end
		if not found then
			table.insert(self.db.registeredFrames, frameName)
		end
	end
	self:UpdateFrameVisibility(frameName, frame)

	if self.db and self.db.debugMode then
		self:Debug("Frame registrado:", frameName)
	end

	return true
end

--- Remove o registro de um frame e da lista persistida
---@param frameName string
---@return boolean
function addon:UnregisterFrame(frameName)
	if self.registeredFrames[frameName] then
		self.registeredFrames[frameName] = nil
		if self.db and type(self.db.registeredFrames) == "table" then
			for i = #self.db.registeredFrames, 1, -1 do
				if self.db.registeredFrames[i] == frameName then
					table.remove(self.db.registeredFrames, i)
					break
				end
			end
		end
		if self.db and self.db.debugMode then
			self:Debug("Frame removido:", frameName)
		end
		return true
	end
	return false
end

--- Restaura os frames salvos em db.registeredFrames com retry progressivo
---@param attempt number
function addon:RestoreRegisteredFrames(attempt)
	attempt = attempt or 1
	local db = self:GetDB() or self.db
	if not db or type(db.registeredFrames) ~= "table" then
		return
	end

	local delays = { 0, 0.5, 1.5, 3, 5 }
	local maxAttempts = #delays

	local function try()
		for _, frameName in ipairs(db.registeredFrames) do
			if type(frameName) == "string" and not self.registeredFrames[frameName] then
				if _G[frameName] then
					self:RegisterFrame(frameName)
				end
			end
		end
		local stillMissing
		for _, frameName in ipairs(db.registeredFrames) do
			if type(frameName) == "string" and not self.registeredFrames[frameName] then
				stillMissing = true
				break
			end
		end
		if stillMissing and attempt < maxAttempts then
			C_Timer.After(delays[attempt + 1] or 5, function()
				self:RestoreRegisteredFrames(attempt + 1)
			end)
		end
	end

	local delay = delays[attempt] or 5
	if delay == 0 then
		try()
	else
		C_Timer.After(delay, try)
	end
end

--- Registra os eventos necessários para monitorar mudanças de estado
function addon:RegisterVisibilityEvents()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	self:RegisterEvent("PLAYER_UPDATE_RESTING")
end

--- Handler de eventos de visibilidade (despachado por Environment.lua)
---@param event FrameEvent
function addon:OnEvent(event, ...)
	if event == "PLAYER_REGEN_DISABLED" then
		-- Entrou em combate: cancela o timer de fade e restaura transparência de combate
		self:CancelOutOfCombatFade()
		C_Timer.After(0.1, function()
			self:UpdateCurrentState()
		end)
	elseif event == "PLAYER_REGEN_ENABLED" then
		-- Saiu de combate: aplica transparência fora de combate, depois agenda fade se ativo
		C_Timer.After(0.1, function()
			self:UpdateCurrentState()
			self:ScheduleOutOfCombatFade()
		end)
	elseif event == "PLAYER_ENTERING_WORLD" or
	       event == "ZONE_CHANGED_NEW_AREA" or
	       event == "GROUP_ROSTER_UPDATE" or
	       event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" or
	       event == "PLAYER_UPDATE_RESTING" then
		C_Timer.After(0.1, function()
			self:UpdateCurrentState()
		end)
	end
end

-- Registro do módulo
-----------------------------------------------------------
addon:RegisterModule({
	id             = "visibility",
	name           = L["Visibility Options"],
	defaultEnabled = true,
	order          = 10,
	chatCommands   = { "register", "unregister", "list", "status" },

	OnEnable = function(self)
		addon:UpdateCurrentState()
		addon:RegisterVisibilityEvents()
		addon:RestoreRegisteredFrames(1)
		addon:UpdateAllFrameVisibility()
		-- Sincronizar controles da UI após carregamento do DB
		C_Timer.After(0.2, function()
			local db = addon:GetDB()
			if db then
				addon.db = db
				if addon.UpdateScenarioControls then addon:UpdateScenarioControls() end
			end
		end)
		-- Integração com outros addons (após 2s para garantir que estejam carregados)
		C_Timer.After(2, function()
			if addon.IntegrateWithCooldownManager then addon:IntegrateWithCooldownManager() end
			if addon.MonitorDropdownCreation then addon:MonitorDropdownCreation() end
		end)
	end,

	OnDisable = function(self)
		addon:CancelOutOfCombatFade()
		for _, frame in pairs(addon.registeredFrames) do
			if frame then
				frame:Show()
				frame:SetAlpha(1)
			end
		end
		addon:UnregisterEvent("PLAYER_ENTERING_WORLD")
		addon:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
		addon:UnregisterEvent("PLAYER_REGEN_DISABLED")
		addon:UnregisterEvent("PLAYER_REGEN_ENABLED")
		addon:UnregisterEvent("GROUP_ROSTER_UPDATE")
		addon:UnregisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
		addon:UnregisterEvent("PLAYER_UPDATE_RESTING")
	end,

	OnChatCommand = function(self, editBox, command, arg1, ...)
		if arg1 == "status" then
			local scenario = addon:GetCurrentScenario()
			addon:Print("Estado atual:")
			addon:Print("  Cenário ativo:", addon.visibilityModeNames[scenario] or scenario)
			addon:Print("  Em combate:", addon.currentState.inCombat and "Sim" or "Não")
			addon:Print("  Na cidade:", addon.currentState.inCity and "Sim" or "Não")
			addon:Print("  Em instância PVE:", addon.currentState.inInstancePVE and "Sim" or "Não")
			addon:Print("  Em instância PvP:", addon.currentState.inInstancePVP and "Sim" or "Não")
			addon:Print("  No mundo aberto:", addon.currentState.inOpenWorld and "Sim" or "Não")
			if addon.currentState.instanceType then
				addon:Print("  Tipo de instância:", addon.currentState.instanceType)
			end
			if addon.db and addon.db.scenarios then
				for key, name in pairs(addon.visibilityModeNames) do
					local cfg = addon:GetScenarioConfig(key)
					addon:Print(string.format("  [%s] %s: trans %.0f%%/%.0f%%",
						name, cfg.enabled and "ON" or "OFF",
						cfg.transparencyInCombat * 100, cfg.transparencyOutOfCombat * 100))
				end
			end
		elseif arg1 == "register" then
			local frameName = (...)
			if frameName then
				if addon:RegisterFrame(frameName) then
					addon:Print("Frame registrado:", frameName)
				else
					addon:Print("Erro ao registrar frame:", frameName)
				end
			else
				addon:Print("Uso: /wowp register <nomeFrame>")
			end
		elseif arg1 == "unregister" then
			local frameName = (...)
			if frameName then
				if addon:UnregisterFrame(frameName) then
					addon:Print("Frame removido:", frameName)
				else
					addon:Print("Frame não encontrado:", frameName)
				end
			else
				addon:Print("Uso: /wowp unregister <nomeFrame>")
			end
		elseif arg1 == "list" then
			local count = 0
			for frameName, _ in pairs(addon.registeredFrames) do
				addon:Print("  -", frameName)
				count = count + 1
			end
			if count == 0 then
				addon:Print("Nenhum frame registrado")
			else
				addon:Print(string.format("Total: %d frame(s)", count))
			end
		end
	end,
})
