-------------------------------------------------------------------------------
-- iMorph Outfits - Editor Dialog
-- Create / edit / delete / apply modal. Owns `addon.editIndex`.
-------------------------------------------------------------------------------

local addon = iMorphOutfits

local editDialog = CreateFrame("Frame", "IMO_EditDialog", UIParent, "BackdropTemplate")
addon.editDialog = editDialog
editDialog:SetSize(310, 410)
editDialog:SetPoint("CENTER")
editDialog:SetMovable(true)
editDialog:EnableMouse(true)
editDialog:RegisterForDrag("LeftButton")
editDialog:SetScript("OnDragStart", editDialog.StartMoving)
editDialog:SetScript("OnDragStop", editDialog.StopMovingOrSizing)
editDialog:SetFrameStrata("DIALOG")
editDialog:Hide()

editDialog:SetBackdrop({
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
editDialog:SetBackdropColor(0.05, 0.05, 0.05, 0.95)

local dialogTitle = editDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
dialogTitle:SetPoint("TOPLEFT", 15, -15)
dialogTitle:SetText("Edit Outfit")

addon.editIndex = nil

local function CreateLabelAndEditBox(parent, labelName, yOffset, height, multiLine)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, yOffset)
	label:SetText(labelName)

	local ebContainer = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	ebContainer:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
	ebContainer:SetSize(280, height)
	ebContainer:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	ebContainer:SetBackdropColor(0.15, 0.15, 0.15, 1)

	local eb
	if multiLine then
		local sFrame = CreateFrame("ScrollFrame", nil, ebContainer, "UIPanelScrollFrameTemplate")
		sFrame:SetPoint("TOPLEFT", 6, -6)
		sFrame:SetPoint("BOTTOMRIGHT", -26, 6)

		eb = CreateFrame("EditBox", nil, sFrame)
		eb:SetSize(248, height - 12)
		eb:SetMultiLine(true)
		eb:SetAutoFocus(false)
		eb:SetFontObject("GameFontHighlight")
		eb:SetTextInsets(2, 2, 2, 2)
		sFrame:SetScrollChild(eb)

		eb:SetScript("OnTextChanged", function()
			sFrame:UpdateScrollChildRect()
		end)

		sFrame:EnableMouse(true)
		sFrame:SetScript("OnMouseDown", function()
			eb:SetFocus()
		end)
	else
		eb = CreateFrame("EditBox", nil, ebContainer)
		eb:SetAllPoints(ebContainer)
		eb:SetTextInsets(8, 8, 8, 8)
		eb:SetFontObject("GameFontHighlight")
		eb:SetAutoFocus(false)
		eb:SetMultiLine(false)
	end

	ebContainer:EnableMouse(true)
	ebContainer:SetScript("OnMouseDown", function()
		eb:SetFocus()
	end)

	eb:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)

	addon.RegisterEditBox(eb)
	return eb
end

local nameInput = CreateLabelAndEditBox(editDialog, "Outfit Name:", -45, 26, false)
local textInput = CreateLabelAndEditBox(editDialog, "Macro Body (Commands):", -100, 120, true)
local noteInput = CreateLabelAndEditBox(editDialog, "Note / Explanation:", -255, 75, true)

local saveBtn = CreateFrame("Button", nil, editDialog, "UIPanelButtonTemplate")
saveBtn:SetSize(90, 24)
saveBtn:SetPoint("BOTTOMLEFT", editDialog, "BOTTOMLEFT", 15, 15)
saveBtn:SetText("Save")

local deleteBtn = CreateFrame("Button", nil, editDialog, "UIPanelButtonTemplate")
deleteBtn:SetSize(90, 24)
deleteBtn:SetPoint("LEFT", saveBtn, "RIGHT", 5, 0)
deleteBtn:SetText("Delete")

local dialogApplyBtn = CreateFrame("Button", nil, editDialog, "UIPanelButtonTemplate")
dialogApplyBtn:SetSize(90, 24)
dialogApplyBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 5, 0)
dialogApplyBtn:SetText("Apply")

local dialogClose = CreateFrame("Button", nil, editDialog, "UIPanelCloseButton")
dialogClose:SetPoint("TOPRIGHT", -5, -5)
dialogClose:SetScript("OnClick", function()
	addon.CloseEditor()
end)

-------------------------------------------------------------------------------
-- Open / Close
-------------------------------------------------------------------------------
function addon.OpenEditor(index)
	addon.editIndex = index
	if index then
		local data = addon.DB[index]
		dialogTitle:SetText("Edit: " .. (data.name or ""))
		nameInput:SetText(data.name or "")
		textInput:SetText(data.body or "")
		noteInput:SetText(data.note or "")
		saveBtn:SetText("Update")
		deleteBtn:Enable()
		dialogApplyBtn:Enable()
	else
		dialogTitle:SetText("New Outfit")
		nameInput:SetText("")
		textInput:SetText("")
		noteInput:SetText("")
		saveBtn:SetText("Save New")
		deleteBtn:Disable()
		dialogApplyBtn:Disable()
	end
	editDialog:Show()
	addon.RefreshList()
end

function addon.CloseEditor()
	editDialog:Hide()
	addon.editIndex = nil
	addon.UnfocusAll()
	addon.RefreshList()
end

-------------------------------------------------------------------------------
-- Save / Delete / Apply
-------------------------------------------------------------------------------
saveBtn:SetScript("OnClick", function()
	local name = nameInput:GetText()
	local body = textInput:GetText()
	local note = noteInput:GetText()

	if name == "" or body == "" then
		addon.SetStatus("Outfit missing Name or Commands!", true)
		return
	end

	if addon.editIndex then
		local wasFavorite = addon.DB[addon.editIndex].isFavorite
		addon.DB[addon.editIndex] = {
			name = name,
			body = body,
			note = note,
			isFavorite = wasFavorite,
		}
		addon.SetStatus("Outfit updated successfully!", false)
	else
		addon.DB[#addon.DB + 1] = { name = name, body = body, note = note }
		addon.SetStatus("Outfit saved successfully!", false)
	end
	addon.CloseEditor()
end)

deleteBtn:SetScript("OnClick", function()
	if addon.editIndex then
		local data = addon.DB[addon.editIndex]
		table.remove(addon.DB, addon.editIndex)
		addon.SetStatus("Outfit layout deleted: " .. (data and data.name or ""), true)
		addon.CloseEditor()
	end
end)

dialogApplyBtn:SetScript("OnClick", function()
	local body = textInput:GetText()
	if body ~= "" then
		addon.ApplyOutfit({ body = body })
		addon.SetStatus("Commands executed!", false)
	end
end)
