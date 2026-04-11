---@class addon
local addon = select(2, ...)

-- WoW API
-----------------------------------------------------------
local _G = _G

-- UI
-----------------------------------------------------------
-- A janela customizada foi removida; toda a configuração do addon
-- é feita pelo painel nativo em Interface > Opções > AddOns > WoWPersonal.

--- Abre o painel nativo de configurações do WoWPersonal.
--- Chamado pelo botão do minimapa e pelo comando /wowp.
function addon:ToggleUI()
	local Settings = _G["Settings"]
	if Settings and self.category then
		Settings.OpenToCategory(self.category)
	end
end
