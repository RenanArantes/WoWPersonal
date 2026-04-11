---@class addon
local addon = select(2, ...)

-- Lua API
-----------------------------------------------------------
local math = math

-- WoW API
-----------------------------------------------------------
local _G = _G
local CreateFrame = _G.CreateFrame
local Minimap = _G.Minimap
local UIParent = _G.UIParent
local GameTooltip = _G.GameTooltip
local GetCursorPosition = _G.GetCursorPosition
local C_Timer = _G.C_Timer

-- Botão no Minimapa
-----------------------------------------------------------

--- Calcula o raio correto para posicionar o botão no anel externo do minimapa.
local function GetMinimapRadius()
	local minimapRadius = math.min(Minimap:GetWidth(), Minimap:GetHeight()) / 2
	return minimapRadius + 8
end

--- Cria o botão no minimapa
function addon:CreateMinimapButton()
	if self.minimapButton then return end

	if not self.db.minimapButtonAngle then
		self.db.minimapButtonAngle = 225
	end

	local button = CreateFrame("Button", "WoWPersonalMinimapButton", Minimap)
	button:SetSize(32, 32)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:EnableMouse(true)
	button:SetMovable(true)
	button:RegisterForClicks("AnyUp")
	button:RegisterForDrag("LeftButton")

	-- Fundo circular (mesma textura usada pelo WoW nativamente nos botões de minimapa)
	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetSize(20, 20)
	bg:SetPoint("CENTER", button, "CENTER", 0, 0)

	-- Ícone central
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	icon:SetTexture("Interface\\Icons\\Spell_Shadow_Teleport")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	-- Borda circular (overlay, 53×53 — tamanho padrão da borda de tracking)
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

	-- Destaque ao passar o mouse
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	-- Tooltip
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("WoWPersonal", 1, 1, 1)
		GameTooltip:AddLine("Clique para abrir a interface", 1, 1, 1, true)
		GameTooltip:Show()
	end)

	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Click handler (ignora cliques que foram precedidos de drag)
	button:SetScript("OnClick", function(self, mouseButton)
		if self.wasDragged then return end
		if mouseButton == "LeftButton" then
			addon:ToggleUI()
		end
	end)

	-- Drag: recalcula ângulo em relação ao centro do minimapa
	button:SetScript("OnDragStart", function(self)
		self.wasDragged = false
		self:SetScript("OnUpdate", function(s)
			local px, py = GetCursorPosition()
			local scale = UIParent:GetEffectiveScale()
			px, py = px / scale, py / scale
			local cx, cy = Minimap:GetCenter()
			if not cx or not cy then return end
			local angle = math.deg(math.atan2(py - cy, px - cx))
			if angle < 0 then angle = angle + 360 end
			addon.db.minimapButtonAngle = angle
			s.wasDragged = true
			s:UpdatePosition()
		end)
	end)

	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		-- Pequeno delay para evitar que o OnClick dispare após o drag
		C_Timer.After(0.05, function()
			if addon.minimapButton then
				addon.minimapButton.wasDragged = nil
			end
		end)
	end)

	--- Reposiciona o botão no anel externo do minimapa com o ângulo salvo
	function button:UpdatePosition()
		local angle = addon.db.minimapButtonAngle or 225
		local radius = GetMinimapRadius()
		local x = math.cos(math.rad(angle)) * radius
		local y = math.sin(math.rad(angle)) * radius
		self:ClearAllPoints()
		self:SetPoint("CENTER", Minimap, "CENTER", x, y)
	end

	button:UpdatePosition()
	self.minimapButton = button
end
