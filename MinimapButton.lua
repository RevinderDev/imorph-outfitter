-------------------------------------------------------------------------------
-- iMorph Outfits - Minimap Button
-------------------------------------------------------------------------------

local addon = iMorphOutfits
local math = math

local miniButton = CreateFrame("Button", "IMO_MinimapButton", Minimap)
miniButton:SetSize(31, 31)
miniButton:SetFrameLevel(Minimap:GetFrameLevel() + 2)
miniButton:SetToplevel(true)
miniButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local iconTex = miniButton:CreateTexture(nil, "BACKGROUND")
iconTex:SetSize(20, 20)
iconTex:SetPoint("CENTER", 0, 0)
iconTex:SetTexture("Interface\\Icons\\INV_Chest_Cloth_23")

local borderTex = miniButton:CreateTexture(nil, "OVERLAY")
borderTex:SetSize(53, 53)
borderTex:SetPoint("TOPLEFT", -1, 1)
borderTex:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function RepositionMinimapButton()
	local angle = addon.DB.minimapPos or 45
	local radius = 80
	local x = math.cos(math.rad(angle)) * radius
	local y = math.sin(math.rad(angle)) * radius
	miniButton:ClearAllPoints()
	miniButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end
addon.RepositionMinimapButton = RepositionMinimapButton

miniButton:RegisterForDrag("LeftButton")
miniButton:SetScript("OnDragStart", function(self)
	self:LockHighlight()
	self:SetScript("OnUpdate", function()
		local mx, my = Minimap:GetCenter()
		local cx, cy = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		cx, cy = cx / scale, cy / scale
		local angle = math.deg(math.atan2(cy - my, cx - mx))
		addon.DB.minimapPos = angle
		RepositionMinimapButton()
	end)
end)

miniButton:SetScript("OnDragStop", function(self)
	self:SetScript("OnUpdate", nil)
	self:UnlockHighlight()
end)

miniButton:SetScript("OnClick", function()
	addon.ToggleMainFrame()
end)

miniButton:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText("iMorph Outfits", 1, 1, 1)
	GameTooltip:AddLine("by Revinder", 0.7, 0.7, 0.7)
	GameTooltip:AddLine(
		"\n|cffffaa00[Left-Click]|r Toggle Wardrobe Grid\n|cffffaa00[Drag Button]|r Reposition Around Minimap",
		1,
		1,
		1,
		true
	)
	GameTooltip:Show()
end)
miniButton:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

addon.OnInit(function()
	RepositionMinimapButton()
end)
