---@class addon
local addon = select(2, ...)

-- Lua API
-----------------------------------------------------------
local ipairs = ipairs
local pairs = pairs
local table = table

-- WoW API
-----------------------------------------------------------
local _G = _G

-- Coordenador principal do addon.
-- Inicializa módulos registrados em Modules/ e delega comandos de chat.
-----------------------------------------------------------

--- Retorna os módulos ordenados pelo campo `order` (menor = primeiro)
---@return table
local function GetOrderedModules()
	local list = {}
	for _, def in pairs(addon.modules) do
		list[#list + 1] = def
	end
	table.sort(list, function(a, b) return (a.order or 100) < (b.order or 100) end)
	return list
end

--- Inicialização: registra comandos de chat
function addon:OnInit()
	self:RegisterChatCommand("wowp")
	self:RegisterChatCommand("wowpersonal")
end

--- Habilita todos os módulos ativos (em ordem), depois cria a UI e o botão do minimapa
function addon:OnEnable()
	for _, def in ipairs(GetOrderedModules()) do
		if self:IsModuleEnabled(def.id) and def.OnEnable then
			def:OnEnable()
		end
	end
	if self.CreateMinimapButton then self:CreateMinimapButton() end
	self:Print("Addon habilitado. Use /wowp para abrir a interface.")
end

--- Handler de comandos de chat.
--- Comandos globais: (vazio) abre UI, options, debug.
--- Outros comandos são delegados ao módulo que os declara em `chatCommands`.
---@param editBox table
---@param command string
---@param arg1 string
function addon:OnChatCommand(editBox, command, arg1, ...)
	if not arg1 or arg1 == "" then
		if self.ToggleUI then self:ToggleUI() end
		return
	end

	if arg1 == "options" then
		local Settings = _G["Settings"]
		if Settings and self.category then
			Settings.OpenToCategory(self.category)
		else
			self:Print("Opções disponíveis em: Interface > Opções > AddOns > WoWPersonal")
		end
		return
	end

	if arg1 == "debug" then
		if self.db then
			self.db.debugMode = not self.db.debugMode
			self:Print("Modo de depuração:", self.db.debugMode and "Ativado" or "Desativado")
		end
		return
	end

	-- Delegar para o módulo que declara este subcomando
	for _, def in ipairs(GetOrderedModules()) do
		if def.chatCommands and def.OnChatCommand then
			for _, cmd in ipairs(def.chatCommands) do
				if cmd == arg1 then
					def:OnChatCommand(editBox, command, arg1, ...)
					return
				end
			end
		end
	end

	self:Print("Comando não reconhecido. Use /wowp para abrir a interface.")
end
