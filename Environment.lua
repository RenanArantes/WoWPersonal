-- Retrieve addon folder name, and our local, private namespace.
---@type string
local addonName = ...
---@class addon
local addon = select(2, ...)

-- Lua API
-----------------------------------------------------------
local string_gsub = string.gsub
local string_find = string.find
local string_split = string.split

-- WoW API
-----------------------------------------------------------
local _G = _G
local SlashCmdList = _G["SlashCmdList"]

-- Nome exato do SavedVariable (deve ser idêntico ao .toc)
local SV_NAME = "WoWPersonal_DB"

-- Config padrão por cenário (cidade, instância PVE, PvP, mundo aberto)
local SCENARIO_DEFAULTS = {
	enabled = true,
	transparencyInCombat = 1.0,
	transparencyOutOfCombat = 1.0,
}

-- Valores padrão (única fonte; não depender de Core.lua)
local DEFAULTS = {
	debugMode = false,
	minimapButtonAngle = 45,
	-- Lista de nomes de frames a aplicar visibilidade (restaurada ao carregar)
	registeredFrames = {},
	-- Estado de habilitação por módulo { [id] = { enabled = bool } }
	modules = {},
	scenarios = {
		city = { enabled = true, transparencyInCombat = 1.0, transparencyOutOfCombat = 1.0 },
		instance_pve = { enabled = true, transparencyInCombat = 1.0, transparencyOutOfCombat = 1.0 },
		instance_pvp = { enabled = true, transparencyInCombat = 1.0, transparencyOutOfCombat = 1.0 },
		open_world = { enabled = true, transparencyInCombat = 1.0, transparencyOutOfCombat = 1.0 },
	},
}

--- Mescla defaults na tabela existente sem substituir chaves já presentes (recursivo para tabelas).
local function CopyDefaults(dst, src)
	if type(dst) ~= "table" then
		dst = {}
	end
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" then
			CopyDefaults(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = (type(v) == "table") and {} or v
			if type(v) == "table" then
				CopyDefaults(dst[k], v)
			end
		end
	end
	return dst
end

--- Migra DB antigo (visibilityMode + transparencyInCombat/OutOfCombat) para estrutura por cenário.
local function MigrateFromOldFormat(db)
	if db.visibilityMode == nil and db.scenarios then
		return -- Já está no formato novo
	end
	if type(db.scenarios) ~= "table" then
		db.scenarios = {}
	end
	local oldMode = db.visibilityMode or "city"
	local tIn = db.transparencyInCombat
	local tOut = db.transparencyOutOfCombat
	for _, key in ipairs({ "city", "instance_pve", "instance_pvp", "open_world" }) do
		if type(db.scenarios[key]) ~= "table" then
			db.scenarios[key] = {}
		end
		CopyDefaults(db.scenarios[key], SCENARIO_DEFAULTS)
		db.scenarios[key].enabled = (key == oldMode)
		if tIn ~= nil then db.scenarios[key].transparencyInCombat = tIn end
		if tOut ~= nil then db.scenarios[key].transparencyOutOfCombat = tOut end
	end
	-- Remover chaves antigas para evitar confusão (opcional; o código novo ignora)
	db.visibilityMode = nil
	db.transparencyInCombat = nil
	db.transparencyOutOfCombat = nil
	db.transparency = nil
end

--- Retorna a tabela de dados persistidos (sempre a que o WoW salva).
--- Não cria a tabela se ainda for nil (SavedVariables podem não ter sido carregadas).
--- Use InitDB() no ADDON_LOADED para garantir que a tabela existe antes de usar.
function addon:GetDB()
	local db = _G[SV_NAME]
	if type(db) ~= "table" then
		return nil
	end
	CopyDefaults(db, DEFAULTS)
	MigrateFromOldFormat(db)
	return db
end

--- Garantir que WoWPersonal_DB existe e está preenchida; chamar apenas no ADDON_LOADED.
--- Cria a tabela só se o WoW ainda não tiver carregado do disco (primeira execução).
function addon:InitDB()
	local db = _G[SV_NAME]
	if type(db) ~= "table" then
		_G[SV_NAME] = {}
		db = _G[SV_NAME]
	end
	CopyDefaults(db, DEFAULTS)
	MigrateFromOldFormat(db)
	addon.db = db
	return db
end

-- Registro de módulos (populado pelos arquivos em Modules/ antes do ADDON_LOADED)
addon.modules = {}

--- Registra um módulo de feature. Chamado no carregamento do arquivo do módulo.
--- Campos obrigatórios: id (string), name (string), defaultEnabled (boolean).
--- Campos opcionais: order (number), OnEnable, OnDisable, CreateUISection, AddSettings,
---                   OnUIShow, chatCommands (table), OnChatCommand.
---@param def table
function addon:RegisterModule(def)
	assert(type(def.id) == "string", "Module must have an id (string)")
	self.modules[def.id] = def
end

--- Retorna true se o módulo está habilitado (usa defaultEnabled como fallback).
---@param id string
---@return boolean
function addon:IsModuleEnabled(id)
	if not self.db then return false end
	if type(self.db.modules) ~= "table" then self.db.modules = {} end
	local m = self.db.modules[id]
	if type(m) ~= "table" then
		self.db.modules[id] = {}
		m = self.db.modules[id]
	end
	if m.enabled == nil then
		local def = self.modules[id]
		m.enabled = def and (def.defaultEnabled ~= false) or false
	end
	return m.enabled == true
end

--- Habilita ou desabilita um módulo em runtime; persiste e chama os lifecycle hooks.
---@param id string
---@param enabled boolean
function addon:SetModuleEnabled(id, enabled)
	if not self.db then return end
	if type(self.db.modules) ~= "table" then self.db.modules = {} end
	if type(self.db.modules[id]) ~= "table" then self.db.modules[id] = {} end
	self.db.modules[id].enabled = enabled
	local def = self.modules[id]
	if not def then return end
	if enabled and def.OnEnable then
		def:OnEnable()
	elseif not enabled and def.OnDisable then
		def:OnDisable()
	end
end

addon.eventFrame = CreateFrame("Frame", addonName .. "EventFrame", UIParent)

-- Should mostly be used for debugging
function addon:Print(...)
	print("|cff33ff99" .. addonName .. ":|r", ...)
end

function addon:Debug(...)
	--[==[@debug@
	print("|cff33ff99" .. addonName .. ":|r", ...)
	--@end-debug@]==]
end

-- Parse chat input arguments
local parse = function(msg)
	msg = string_gsub(msg, "^%s+", "") -- Remove spaces at the start.
	msg = string_gsub(msg, "%s+$", "") -- Remove spaces at the end.
	msg = string_gsub(msg, "%s+", " ") -- Replace all space characters with single spaces.
	if (string_find(msg, "%s")) then
		return string_split(" ", msg) -- If multiple arguments exist, split them into separate return values.
	else
		return msg
	end
end

-- This methods lets you register a chat command, and a callback function or private method name.
-- Your callback will be called as callback(addon, editBox, commandName, ...) where (...) are all the input parameters.
--- Register a chat command under the addon name
---@param command string
---@param callback nil|fun(self: table, editBox: number, commandName: string, ...: string): nil
function addon:RegisterChatCommand(command, callback)
	command = string_gsub(command, "^\\", "")                       -- Remove any backslash at the start.
	command = string.lower(command)                                 -- Make it lowercase, keep it case-insensitive.
	local name = string.upper(addonName .. "_CHATCOMMAND_" .. command) -- Create a unique uppercase name for the command.
	_G["SLASH_" .. name .. "1"] = "/" .. command                    -- Register the chat command, keeping it lowercase.
	SlashCmdList[name] = function(msg, editBox)
		local func = self[callback] or callback or addon.OnChatCommand
		if (func) then
			func(addon, editBox, command, parse(string.lower(msg)))
		end
	end
end

-- Event API
-----------------------------------------------------------
-- Proxy event registering to the addon namespace.
-- The 'self' within these should refer to our proxy frame,
-- which has been passed to this environment method as the 'self'.
---@param event FrameEvent
addon.RegisterEvent = function(_, event) addon.eventFrame:RegisterEvent(event) end
addon.RegisterUnitEvent = function(_, ...) addon.eventFrame:RegisterUnitEvent(...) end
---@param event FrameEvent
addon.UnregisterEvent = function(_, event) addon.eventFrame:UnregisterEvent(event) end
addon.UnregisterAllEvents = function(_) addon.eventFrame:UnregisterAllEvents() end
addon.IsEventRegistered = function(_, ...) return addon.eventFrame:IsEventRegistered(...) end

-- Event Dispatcher and Initialization Handler
-----------------------------------------------------------
-- Assign our event script handler,
-- which runs our initialization methods,
-- and dispatches event to the addon namespace.
addon.eventFrame:RegisterEvent("ADDON_LOADED")
addon.eventFrame:SetScript("OnEvent", function(self, event, ...)
	if (event == "ADDON_LOADED") then
		-- Nothing happens before this has fired for your addon.
		-- When it fires, we remove the event listener
		-- and call our initialization method.
		if ((...) == addonName) then
			addon.eventFrame:UnregisterEvent("ADDON_LOADED")
			-- Só criar a tabela aqui: antes disso GetDB() retorna nil para não sobrescrever
			-- a tabela que o WoW carrega do disco (LoadSavedVariablesFirst).
			addon:InitDB()
			-- Garantir que db.modules existe e semear defaults para módulos já registrados.
			if type(addon.db.modules) ~= "table" then addon.db.modules = {} end
			for id, def in pairs(addon.modules) do
				if type(addon.db.modules[id]) ~= "table" then
					addon.db.modules[id] = { enabled = (def.defaultEnabled ~= false) }
				elseif addon.db.modules[id].enabled == nil then
					addon.db.modules[id].enabled = (def.defaultEnabled ~= false)
				end
			end
			-- Call the initialization method.
			if (addon.OnInit) then
				addon:OnInit()
			end
			-- Registrar opções na aba AddOns das Opções do jogo (igual a CooldownManagerCentered / !WilduTools)
			if (addon.CreateConfigPanel) then
				addon:CreateConfigPanel()
			end
			-- If this was a load-on-demand addon, then we might be logged in already.
			-- If that is the case, directly run the enabling method.
			if (IsLoggedIn()) then
				if (addon.OnEnable) then
					addon:OnEnable()
				end
			else
				-- If this is a regular always-load addon,
				-- we're not yet logged in, and must listen for this.
				addon.eventFrame:RegisterEvent("PLAYER_LOGIN")
			end
			-- Return. We do not wish to forward the loading event
			-- for our own addon to the namespace event handler.
			-- That is what the initialization method exists for.
			return
		end
	elseif (event == "PLAYER_LOGIN") then
		-- This event only ever fires once on a reload,
		-- and anything you wish done at this event,
		-- should be put in the namespace enable method.
		addon.eventFrame:UnregisterEvent("PLAYER_LOGIN")
		-- Call the enabling method.
		if (addon.OnEnable) then
			addon:OnEnable()
		end
		-- Return. We do not wish to forward this
		-- to the namespace event handler.
		return
	end
	-- Forward other events than our two initialization events
	-- to the addon namespace's event handler.
	-- Note that you can always register more ADDON_LOADED
	-- if you wish to listen for other addons loading.
	if (addon[event] and type(addon[event]) == "function") then
		addon[event](addon, event, ...)
	else
		if (addon.OnEvent) then
			addon:OnEvent(event, ...)
		end
	end
end)
