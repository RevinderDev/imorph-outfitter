local addonName = "iMorphOutfits"

-- Globally initialized database for outfit configurations (Preserved)
iMorphOutfitsDB = iMorphOutfitsDB or {}

local frame = CreateFrame("Frame", "IMO_MainFrame", UIParent, "BackdropTemplate")
frame:SetHeight(450)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()

-- Main Window Backdrop Styling
frame:SetBackdrop({
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
frame:SetBackdropColor(0, 0, 0, 0.9)

-- Title Heading (iMorph Outfits)
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 15, -15)

-- Author Credit Subtitle
local authorText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
authorText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
authorText:SetTextColor(1, 1, 1, 1) -- Pure White
authorText:SetText("by Revinder")

-- Status Message Display String (Bottom Alignment)
local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusText:SetText("")

local statusTimer
local function SetStatus(text, isError)
	if isError then
		statusText:SetTextColor(1, 0.3, 0.3) -- Warning Red
	else
		statusText:SetTextColor(0.3, 1, 0.3) -- Success Green
	end
	statusText:SetText(text)

	if statusTimer then
		statusTimer:Cancel()
	end
	statusTimer = C_Timer.NewTimer(3.5, function()
		statusText:SetText("")
	end)
end

-- Close Button
local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -5, -5)

-- Forward declarations for dynamic input contexts
local searchContainer, searchBox
local layoutBtn, layoutMenu
local resetBtn
local editDialog
local nameInput, textInput, noteInput
local saveBtn, deleteBtn

local function UnfocusAllInputBoxes()
	if searchBox then
		searchBox:ClearFocus()
	end
	if nameInput then
		nameInput:ClearFocus()
	end
	if textInput then
		textInput:ClearFocus()
	end
	if noteInput then
		noteInput:ClearFocus()
	end
end

-- Top Right "Reset Outfit" Button Configuration
resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
resetBtn:SetText("Reset Outfit")
resetBtn:SetScript("OnClick", function()
	local editBox = ChatFrame1EditBox
	if editBox then
		local backupText = editBox:GetText()
		local backupChatType = editBox:GetAttribute("chatType")

		editBox:SetAttribute("chatType", "SAY")
		editBox:SetText(".reset")
		ChatEdit_SendText(editBox, 0)

		editBox:SetAttribute("chatType", backupChatType)
		editBox:SetText(backupText)
		SetStatus("Outfit reset command sent!", false)
	else
		SetStatus("Error: Chat frame not found.", true)
	end
	UnfocusAllInputBoxes()
end)

-- Shared Core Outfit Executor Engine
local function ApplyOutfit(data)
	if not data or not data.body or data.body == "" then
		return
	end
	local editBox = ChatFrame1EditBox
	if editBox then
		local backupChatType = editBox:GetAttribute("chatType")
		for line in string.gmatch(data.body, "[^\r\n]+") do
			if line and line ~= "" then
				line = string.gsub(line, "^%s*(.-)%s*$", "%1")
				local backupText = editBox:GetText()
				editBox:SetAttribute("chatType", "SAY")
				editBox:SetText(line)
				ChatEdit_SendText(editBox, 0)
				editBox:SetText(backupText)
			end
		end
		editBox:SetAttribute("chatType", backupChatType)
	end
end

-------------------------------------------------------------------------------
-- DYNAMIC SEARCH BAR
-------------------------------------------------------------------------------
searchContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
searchContainer:SetHeight(24)
searchContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -52)
searchContainer:SetBackdrop({
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
searchContainer:SetBackdropColor(0.15, 0.15, 0.15, 1)

searchBox = CreateFrame("EditBox", nil, searchContainer)
searchBox:SetAllPoints(searchContainer)
searchBox:SetTextInsets(8, 8, 0, 0)
searchBox:SetFontObject("GameFontHighlight")
searchBox:SetAutoFocus(false)
searchBox:SetMultiLine(false)

local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
searchPlaceholder:SetText("Search...")

searchBox:SetScript("OnTextChanged", function(self)
	if self:GetText() == "" then
		searchPlaceholder:Show()
	else
		searchPlaceholder:Hide()
	end
	if RefreshMacroList then
		RefreshMacroList()
	end
end)
searchBox:SetScript("OnEscapePressed", function(self)
	self:ClearFocus()
end)

-------------------------------------------------------------------------------
-- OUTFIT LIST GRID PANEL (Right anchor removed to let SetWidth dictate size)
-------------------------------------------------------------------------------
local listInset = CreateFrame("Frame", nil, frame, "BackdropTemplate")
listInset:SetPoint("TOPLEFT", 15, -82)
listInset:SetPoint("BOTTOM", frame, "BOTTOM", 0, 44)
listInset:SetBackdrop({
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
listInset:SetBackdropColor(0.05, 0.05, 0.05, 0.7)

local scrollFrame = CreateFrame("ScrollFrame", "IMO_ScrollFrame", listInset, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 5, -5)
scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)

local scrollContent = CreateFrame("Frame", "IMO_ScrollContent", scrollFrame)
scrollContent:SetSize(170, 1)
scrollFrame:SetScrollChild(scrollContent)

-------------------------------------------------------------------------------
-- DYNAMIC GRID RESIZER ENGINE (Handles Adaptive Hug Sizing)
-------------------------------------------------------------------------------
layoutBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
layoutBtn:SetPoint("LEFT", searchContainer, "RIGHT", 5, 0)

layoutMenu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
layoutMenu:SetHeight(106)
layoutMenu:SetPoint("TOPLEFT", layoutBtn, "BOTTOMLEFT", 0, -2)
layoutMenu:SetBackdrop({
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
layoutMenu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
layoutMenu:SetFrameStrata("DIALOG")
layoutMenu:Hide()

local layouts = {
	{ name = "1xN (Small)", cols = 1 },
	{ name = "2xN (Med)", cols = 2 },
	{ name = "3xN (Large)", cols = 3 },
	{ name = "4xN (Alex)", cols = 4 },
}

function SetGridLayout(cols)
	iMorphOutfitsDB.columnLayout = cols
	layoutBtn:SetText("Size: " .. layouts[cols].name)
	layoutMenu:Hide()

	-- Dynamic micro-scaling adjustments for top control items to avoid cramped layouts
	if cols == 1 then
		title:SetFontObject("GameFontNormal")
		title:SetText("iMorph Outfits")
		resetBtn:SetSize(82, 20)
		resetBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -13)
		searchContainer:SetWidth(75)
		layoutBtn:SetSize(105, 24)
	else
		title:SetFontObject("GameFontNormalLarge")
		title:SetText("iMorph Outfits")
		resetBtn:SetSize(100, 22)
		resetBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -38, -14)
		searchContainer:SetWidth(120)
		layoutBtn:SetSize(140, 24)
	end

	-- Update dropdown window element properties dynamically
	layoutMenu:SetWidth(layoutBtn:GetWidth())
	for i, mBtn in ipairs(layoutMenu.buttons) do
		mBtn:SetSize(layoutBtn:GetWidth() - 10, 22)
		mBtn:SetPoint("TOPLEFT", 5, -5 - ((i - 1) * 24))
	end

	local btnWidth = 150
	local xSpacing = 6
	local contentWidth = (cols * btnWidth) + ((cols - 1) * xSpacing)

	-- Recalculate container bounding metrics to wrap around buttons cleanly
	local insetWidth = contentWidth + 30
	listInset:SetWidth(insetWidth)
	scrollContent:SetWidth(contentWidth)

	-- Seamlessly match outer window frame margins to custom encapsulated list widths
	local topControlsMinWidth = searchContainer:GetWidth() + 5 + layoutBtn:GetWidth() + 30
	local finalFrameWidth = math.max(topControlsMinWidth, insetWidth + 30)
	frame:SetWidth(finalFrameWidth)

	if RefreshMacroList then
		RefreshMacroList()
	end
end

layoutBtn:SetScript("OnClick", function()
	if layoutMenu:IsShown() then
		layoutMenu:Hide()
	else
		layoutMenu:Show()
	end
end)

layoutMenu.buttons = {}
for i, opt in ipairs(layouts) do
	local mBtn = CreateFrame("Button", nil, layoutMenu, "UIPanelButtonTemplate")
	mBtn:SetText(opt.name)
	mBtn:SetScript("OnClick", function()
		SetGridLayout(opt.cols)
	end)
	table.insert(layoutMenu.buttons, mBtn)
end

-------------------------------------------------------------------------------
-- SEPARATE DIALOG PANEL: CREATOR & EDITOR MODAL
-------------------------------------------------------------------------------
editDialog = CreateFrame("Frame", "IMO_EditDialog", UIParent, "BackdropTemplate")
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

local selectedIndex = nil

local function CloseEditor()
	editDialog:Hide()
	selectedIndex = nil
	UnfocusAllInputBoxes()
	if RefreshMacroList then
		RefreshMacroList()
	end
end

local dialogClose = CreateFrame("Button", nil, editDialog, "UIPanelCloseButton")
dialogClose:SetPoint("TOPRIGHT", -5, -5)
dialogClose:SetScript("OnClick", CloseEditor)

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
	else
		eb = CreateFrame("EditBox", nil, ebContainer)
		eb:SetAllPoints(ebContainer)
		eb:SetTextInsets(8, 8, 8, 8)
		eb:SetFontObject("GameFontHighlight")
		eb:SetAutoFocus(false)
		eb:SetMultiLine(false)
	end
	eb:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	return eb
end

nameInput = CreateLabelAndEditBox(editDialog, "Outfit Name:", -45, 26, false)
textInput = CreateLabelAndEditBox(editDialog, "Macro Body (Commands):", -100, 120, true)
noteInput = CreateLabelAndEditBox(editDialog, "Note / Explanation:", -255, 75, true)

saveBtn = CreateFrame("Button", nil, editDialog, "UIPanelButtonTemplate")
saveBtn:SetSize(90, 24)
saveBtn:SetPoint("BOTTOMLEFT", editDialog, "BOTTOMLEFT", 15, 15)
saveBtn:SetText("Save")

deleteBtn = CreateFrame("Button", nil, editDialog, "UIPanelButtonTemplate")
deleteBtn:SetSize(90, 24)
deleteBtn:SetPoint("LEFT", saveBtn, "RIGHT", 5, 0)
deleteBtn:SetText("Delete")

local dialogApplyBtn = CreateFrame("Button", nil, editDialog, "UIPanelButtonTemplate")
dialogApplyBtn:SetSize(90, 24)
dialogApplyBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 5, 0)
dialogApplyBtn:SetText("Apply")

-- Bottom Placement Setup for New Outfit Configuration Button
local newOutfitBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
newOutfitBtn:SetSize(100, 22)
newOutfitBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, 14)
newOutfitBtn:SetText("New Outfit")

statusText:SetPoint("BOTTOMLEFT", newOutfitBtn, "BOTTOMRIGHT", 10, 4)

local function OpenEditor(index)
	selectedIndex = index
	if index then
		local data = iMorphOutfitsDB[index]
		dialogTitle:SetText("Edit: " .. data.name)
		nameInput:SetText(data.name)
		textInput:SetText(data.body)
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
	if RefreshMacroList then
		RefreshMacroList()
	end
end

newOutfitBtn:SetScript("OnClick", function()
	OpenEditor(nil)
end)

saveBtn:SetScript("OnClick", function()
	local name = nameInput:GetText()
	local body = textInput:GetText()
	local note = noteInput:GetText()

	if name == "" or body == "" then
		SetStatus("Outfit missing Name or Commands!", true)
		return
	end

	if selectedIndex then
		local wasFavorite = iMorphOutfitsDB[selectedIndex].isFavorite
		iMorphOutfitsDB[selectedIndex] = { name = name, body = body, note = note, isFavorite = wasFavorite }
		SetStatus("Outfit updated successfully!", false)
	else
		table.insert(iMorphOutfitsDB, { name = name, body = body, note = note })
		SetStatus("Outfit saved successfully!", false)
	end
	CloseEditor()
end)

deleteBtn:SetScript("OnClick", function()
	if selectedIndex then
		table.remove(iMorphOutfitsDB, selectedIndex)
		SetStatus("Outfit layout deleted.", true)
		CloseEditor()
	end
end)

dialogApplyBtn:SetScript("OnClick", function()
	local body = textInput:GetText()
	if body ~= "" then
		ApplyOutfit({ body = body })
		SetStatus("Commands executed!", false)
	end
end)

-------------------------------------------------------------------------------
-- GRID ARCHITECTURE LAYOUT COMPILER ENGINE
-------------------------------------------------------------------------------
local macroButtons = {}

function RefreshMacroList()
	local displayIndex = 1
	local filterText = string.lower(searchBox:GetText() or "")
	local cols = iMorphOutfitsDB.columnLayout or 1

	local btnWidth = 150
	local btnHeight = 30
	local xSpacing = 6
	local ySpacing = 6

	-- Create a temporary display list to force favorites to the top
	local displayList = {}
	local favCount = 0
	local favIndices = {}

	-- Pass 1: Collect filtered favorites
	for i, data in ipairs(iMorphOutfitsDB) do
		if filterText == "" or string.find(string.lower(data.name or ""), filterText, 1, true) then
			if data.isFavorite then
				favCount = favCount + 1
				favIndices[i] = favCount
				table.insert(displayList, { dbIndex = i, data = data })
			end
		end
	end

	-- Pass 2: Collect filtered non-favorites
	for i, data in ipairs(iMorphOutfitsDB) do
		if filterText == "" or string.find(string.lower(data.name or ""), filterText, 1, true) then
			if not data.isFavorite then
				table.insert(displayList, { dbIndex = i, data = data })
			end
		end
	end

	-- Render the UI elements based on our re-ordered displayList
	for _, item in ipairs(displayList) do
		local i = item.dbIndex
		local data = item.data

		local btn = macroButtons[displayIndex]
		if not btn then
			btn = CreateFrame("Button", "IMO_MacroBtn_" .. displayIndex, scrollContent, "BackdropTemplate")
			btn:SetSize(btnWidth, btnHeight)
			btn:SetBackdrop({
				bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true,
				tileSize = 16,
				edgeSize = 12,
				insets = { left = 3, right = 3, top = 3, bottom = 3 },
			})

			btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			btn.text:SetPoint("LEFT", 8, 0)
			btn.text:SetPoint("RIGHT", -42, 0)
			btn.text:SetJustifyH("LEFT")

			btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			macroButtons[displayIndex] = btn
		end

		if not btn.starBtn then
			btn.starBtn = CreateFrame("Button", nil, btn)
			btn.starBtn:SetSize(12, 12)
			btn.starBtn:SetPoint("RIGHT", btn, "RIGHT", -6, 0)

			btn.starTex = btn.starBtn:CreateTexture(nil, "ARTWORK")
			btn.starTex:SetAllPoints()
			btn.starTex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
			btn.starTex:SetTexCoord(0, 0.25, 0, 0.25)

			btn.favText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			btn.favText:SetPoint("RIGHT", btn.starBtn, "LEFT", -2, 0)
			btn.favText:SetTextColor(1, 0.82, 0)
		end

		btn.starBtn:SetScript("OnClick", function()
			iMorphOutfitsDB[i].isFavorite = not iMorphOutfitsDB[i].isFavorite
			RefreshMacroList()
		end)

		local row = math.floor((displayIndex - 1) / cols)
		local col = (displayIndex - 1) % cols
		local xPos = col * (btnWidth + xSpacing)
		local yPos = -row * (btnHeight + ySpacing)

		btn:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", xPos, yPos)
		btn.text:SetText(data.name)

		if data.isFavorite then
			btn.starTex:SetVertexColor(1, 1, 1, 1)
			btn.favText:SetText("#" .. (favIndices[i] or ""))
			btn.favText:Show()
		else
			btn.starTex:SetVertexColor(0.25, 0.25, 0.25, 0.3)
			btn.favText:SetText("")
			btn.favText:Hide()
		end

		if selectedIndex == i and editDialog:IsShown() then
			btn:SetBackdropColor(0.1, 0.4, 0.1, 0.8)
			btn:SetBackdropBorderColor(0, 1, 0, 1)
		else
			btn:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
			btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
		end

		btn:SetScript("OnClick", function(self, button)
			if button == "LeftButton" then
				ApplyOutfit(data)
				SetStatus("Applied: " .. data.name, false)
			elseif button == "RightButton" then
				OpenEditor(i)
			end
		end)

		btn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(data.name, 1, 1, 1)
			if data.note and data.note ~= "" then
				GameTooltip:AddLine("\n|cff00ff00Outfit Note:|r\n" .. data.note, 1, 1, 1, true)
			else
				GameTooltip:AddLine("\n|cff888888No descriptions added.|r")
			end
			GameTooltip:AddLine(
				"\n|cffffaa00[Left-Click]|r Apply Outfit\n|cffffaa00[Right-Click]|r Open Editor Dialog",
				0.7,
				0.7,
				0.7
			)
			GameTooltip:Show()
		end)
		btn:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		btn:Show()
		displayIndex = displayIndex + 1
	end

	for i = displayIndex, #macroButtons do
		if macroButtons[i] then
			macroButtons[i]:Hide()
		end
	end

	local totalRows = math.ceil((displayIndex - 1) / cols)
	scrollContent:SetHeight(math.max(1, totalRows * (btnHeight + ySpacing)))
end

local function ToggleMainFrame()
	if frame:IsShown() then
		frame:Hide()
		CloseEditor()
	else
		frame:Show()
		SetGridLayout(iMorphOutfitsDB.columnLayout or 1)
	end
end

-------------------------------------------------------------------------------
-- MINIMAP BUTTON FRAME GENERATION
-------------------------------------------------------------------------------
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
	local angle = iMorphOutfitsDB.minimapPos or 45
	local radius = 80
	local x = math.cos(math.rad(angle)) * radius
	local y = math.sin(math.rad(angle)) * radius
	miniButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

miniButton:RegisterForDrag("LeftButton")
miniButton:SetScript("OnDragStart", function(self)
	self:LockHighlight()
	self:SetScript("OnUpdate", function()
		local mx, my = Minimap:GetCenter()
		local cx, cy = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		cx, cy = cx / scale, cy / scale

		local angle = math.deg(math.atan2(cy - my, cx - mx))
		iMorphOutfitsDB.minimapPos = angle
		RepositionMinimapButton()
	end)
end)

miniButton:SetScript("OnDragStop", function(self)
	self:SetScript("OnUpdate", nil)
	self:UnlockHighlight()
end)

miniButton:SetScript("OnClick", ToggleMainFrame)

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

-------------------------------------------------------------------------------
-- INITIALIZATION ENGINE & SLASH ROUTING
-------------------------------------------------------------------------------
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and string.lower(arg1) == string.lower(addonName) then
		iMorphOutfitsDB = iMorphOutfitsDB or {}
		if not iMorphOutfitsDB.minimapPos then
			iMorphOutfitsDB.minimapPos = 45
		end
		if not iMorphOutfitsDB.columnLayout then
			iMorphOutfitsDB.columnLayout = 1
		end
		RepositionMinimapButton()
		SetGridLayout(iMorphOutfitsDB.columnLayout)
	end
end)

SLASH_IMORPHOUTFITS1 = "/imo"
SLASH_IMORPHOUTFITS2 = "/rev"

SlashCmdList["IMORPHOUTFITS"] = function(msg)
	msg = string.lower(string.gsub(msg, "^%s*(.-)%s*$", "%1"))
	if msg == "" then
		ToggleMainFrame()
		return
	end

	local cmd, arg = string.match(msg, "^(%S*)%s*(.-)$")
	if cmd == "help" then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00iMorph Outfits Commands Help Menu:|r")
		DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00/rev|r - Toggle main wardrobe visual frame UI layout")
		DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00/rev help|r - Prints this informational configuration overview")
		DEFAULT_CHAT_FRAME:AddMessage(
			"  |cff00ff00/rev random|r - Actively chooses one layout out of all saved options at random"
		)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  |cff00ff00/rev favourite list|r - Outputs sequential catalog indexing numbers and associated names"
		)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  |cff00ff00/rev favourite random|r - Picks one profile strictly isolated within favored definitions"
		)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  |cff00ff00/rev favourite <number>|r - Fires the exact specified favorite profile assignment path"
		)
		return
	elseif cmd == "random" then
		if #iMorphOutfitsDB == 0 then
			return
		end
		local rIdx = math.random(1, #iMorphOutfitsDB)
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cff00ff00iMorph Outfits:|r Random: |cffffaa00" .. iMorphOutfitsDB[rIdx].name .. "|r"
		)
		ApplyOutfit(iMorphOutfitsDB[rIdx])
		return
	elseif cmd == "favourite" or cmd == "favorite" then
		if arg == "list" then
			DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00iMorph Outfits - Active Favorites Catalog:|r")
			local listCount = 0
			for _, d in ipairs(iMorphOutfitsDB) do
				if d.isFavorite then
					listCount = listCount + 1
					DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00#" .. listCount .. "|r: " .. d.name)
				end
			end
			return
		elseif arg == "random" then
			local favs = {}
			for _, d in ipairs(iMorphOutfitsDB) do
				if d.isFavorite then
					table.insert(favs, d)
				end
			end
			if #favs == 0 then
				return
			end
			local rIdx = math.random(1, #favs)
			DEFAULT_CHAT_FRAME:AddMessage(
				"|cff00ff00iMorph Outfits:|r Random Favorite: |cffffaa00" .. favs[rIdx].name .. "|r"
			)
			ApplyOutfit(favs[rIdx])
			return
		else
			local num = tonumber(arg)
			if num then
				local count = 0
				for _, d in ipairs(iMorphOutfitsDB) do
					if d.isFavorite then
						count = count + 1
						if count == num then
							DEFAULT_CHAT_FRAME:AddMessage(
								"|cff00ff00iMorph Outfits:|r Favorite #" .. num .. ": |cffffaa00" .. d.name .. "|r"
							)
							ApplyOutfit(d)
							return
						end
					end
				end
				DEFAULT_CHAT_FRAME:AddMessage("|cffff3333iMorph Outfits Error: Favorite #" .. num .. " not found!|r")
			end
			return
		end
	else
		ToggleMainFrame()
	end
end

