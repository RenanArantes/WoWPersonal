---@class addon
local addon = select(2, ...)
local L = addon.L

-- Lua API
-----------------------------------------------------------
local pairs = pairs

-- WoW API
-----------------------------------------------------------
local _G = _G
local C_Timer = _G.C_Timer

-- Integração com Cooldown Manager
-----------------------------------------------------------

--- Tenta encontrar e integrar com o Cooldown Manager (retry automático)
function addon:IntegrateWithCooldownManager()
	if not _G.CooldownManagerCentered then
		C_Timer.After(1, function()
			self:IntegrateWithCooldownManager()
		end)
		return
	end
	self:HookCooldownManagerVisibility()
end

--- Faz hook no sistema de visibilidade do Cooldown Manager
function addon:HookCooldownManagerVisibility()
	if self.db and self.db.debugMode then
		self:Debug("Tentando integrar com Cooldown Manager...")
	end
	-- Estrutura base para expansão futura conforme a API do Cooldown Manager
end

--- Aplica as configurações de visibilidade a um frame específico do Cooldown Manager
---@param frameName string
---@return boolean
function addon:ApplyVisibilityToCooldownManagerFrame(frameName)
	local frame = _G[frameName]
	if not frame then
		if self.db and self.db.debugMode then
			self:Debug("Frame do Cooldown Manager não encontrado:", frameName)
		end
		return false
	end
	return self:RegisterFrame(frameName, frame)
end

--- Encontra frames do Cooldown Manager via heurística de nome
---@return table
function addon:FindCooldownManagerFrames()
	local frames = {}
	for name, frame in pairs(_G) do
		if type(frame) == "table" and frame.IsShown and frame.Show and frame.Hide then
			if name:match("Cooldown") or name:match("CMC") or name:match("CM") then
				table.insert(frames, name)
			end
		end
	end
	return frames
end
