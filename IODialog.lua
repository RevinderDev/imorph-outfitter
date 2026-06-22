-------------------------------------------------------------------------------
-- iMorph Outfits - Import / Export Dialog
-------------------------------------------------------------------------------

local addon = iMorphOutfits

local ioDialog = CreateFrame("Frame", "IMO_IODialog", UIParent, "BackdropTemplate")
addon.ioDialog = ioDialog
ioDialog:SetSize(330, 260)
ioDialog:SetPoint("CENTER")
ioDialog:SetMovable(true)
ioDialog:EnableMouse(true)
ioDialog:RegisterForDrag("LeftButton")
ioDialog:SetScript("OnDragStart", ioDialog.StartMoving)
ioDialog:SetScript("OnDragStop", ioDialog.StopMovingOrSizing)
ioDialog:SetFrameStrata("DIALOG")
ioDialog:Hide()

ioDialog:SetBackdrop({
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
ioDialog:SetBackdropColor(0.05, 0.05, 0.05, 0.95)

local ioTitle = ioDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
ioTitle:SetPoint("TOPLEFT", 15, -15)

local ioClose = CreateFrame("Button", nil, ioDialog, "UIPanelCloseButton")
ioClose:SetPoint("TOPRIGHT", -5, -5)
ioClose:SetScript("OnClick", function()
	ioDialog:Hide()
	addon.UnfocusAll()
end)

local ioContainer = CreateFrame("Frame", nil, ioDialog, "BackdropTemplate")
ioContainer:SetPoint("TOPLEFT", 15, -45)
ioContainer:SetSize(300, 160)
ioContainer:SetBackdrop({
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
ioContainer:SetBackdropColor(0.15, 0.15, 0.15, 1)

local ioScroll = CreateFrame("ScrollFrame", nil, ioContainer, "UIPanelScrollFrameTemplate")
ioScroll:SetPoint("TOPLEFT", 6, -6)
ioScroll:SetPoint("BOTTOMRIGHT", -26, 6)

local ioEditBox = CreateFrame("EditBox", nil, ioScroll)
ioEditBox:SetSize(268, 148)
ioEditBox:SetMultiLine(true)
ioEditBox:SetAutoFocus(false)
ioEditBox:SetFontObject("GameFontHighlightSmall")
ioEditBox:SetTextInsets(2, 2, 2, 2)
ioScroll:SetScrollChild(ioEditBox)
addon.RegisterEditBox(ioEditBox)

ioEditBox:SetScript("OnTextChanged", function()
	ioScroll:UpdateScrollChildRect()
end)
ioEditBox:SetScript("OnEscapePressed", function(self)
	self:ClearFocus()
end)

ioScroll:EnableMouse(true)
ioScroll:SetScript("OnMouseDown", function()
	ioEditBox:SetFocus()
end)

local ioActionBtn = CreateFrame("Button", nil, ioDialog, "UIPanelButtonTemplate")
ioActionBtn:SetSize(100, 24)
ioActionBtn:SetPoint("BOTTOMLEFT", ioDialog, "BOTTOMLEFT", 15, 15)

local ioCancelBtn = CreateFrame("Button", nil, ioDialog, "UIPanelButtonTemplate")
ioCancelBtn:SetSize(100, 24)
ioCancelBtn:SetPoint("BOTTOMRIGHT", ioDialog, "BOTTOMRIGHT", -15, 15)
ioCancelBtn:SetText("Close")
ioCancelBtn:SetScript("OnClick", function()
	ioDialog:Hide()
	addon.UnfocusAll()
end)

-------------------------------------------------------------------------------
-- Export / Import entry points
-------------------------------------------------------------------------------
function addon.OpenExport()
	if addon.editDialog then
		addon.editDialog:Hide()
	end
	local encoded = addon.EncodeOutfits()
	ioTitle:SetText("Export Outfits (Ctrl+C)")
	ioEditBox:SetText(encoded)
	ioActionBtn:SetText("Highlight")
	ioActionBtn:SetScript("OnClick", function()
		ioEditBox:HighlightText()
		ioEditBox:SetFocus()
		addon.SetStatus("Text highlighted! Copy with Ctrl+C.", false)
	end)
	ioDialog:Show()
	C_Timer.After(0.1, function()
		ioEditBox:HighlightText()
		ioEditBox:SetFocus()
	end)
end

function addon.OpenImport()
	if addon.editDialog then
		addon.editDialog:Hide()
	end
	ioTitle:SetText("Import Outfits (Ctrl+V)")
	ioEditBox:SetText("")
	ioActionBtn:SetText("Import")
	ioActionBtn:SetScript("OnClick", function()
		local text = ioEditBox:GetText()
		if text and text ~= "" then
			local importedCount = addon.DecodeOutfits(text)
			if importedCount > 0 then
				addon.SetStatus(string.format("Imported %d outfits!", importedCount), false)
				ioDialog:Hide()
				addon.UnfocusAll()
				addon.RefreshList()
			else
				addon.SetStatus("Error: Invalid import text string.", true)
			end
		else
			addon.SetStatus("Error: Paste data layout first.", true)
		end
	end)
	ioDialog:Show()
	ioEditBox:SetFocus()
end
