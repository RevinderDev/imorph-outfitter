-------------------------------------------------------------------------------
-- iMorph Outfits - Main Frame
-- Main window, search bar, outfit grid, layout menu, bottom action bar,
-- RefreshList (grid compiler) and SetGridLayout (dynamic resizer).
--
-- Performance notes:
--  * Macro button scripts are set ONCE at creation and read live data from
--    `self.dbIndex` + addon.DB - no closures are re-created per refresh.
--  * RefreshList rebuilds the visible set in a single pass with a stable
--    favorites-first sort, and calls ClearAllPoints() before SetPoint().
-------------------------------------------------------------------------------

local addon = iMorphOutfits
local string = string
local math = math
local ipairs = ipairs
local table = table

-- Grid metrics (shared with SetGridLayout)
local BTN_WIDTH = 150
local BTN_HEIGHT = 30
local X_SPACING = 6
local Y_SPACING = 6

-------------------------------------------------------------------------------
-- Main window
-------------------------------------------------------------------------------
local frame = CreateFrame("Frame", "IMO_MainFrame", UIParent, "BackdropTemplate")
addon.frame = frame
frame:SetHeight(450)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()

frame:SetBackdrop({
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
frame:SetBackdropColor(0, 0, 0, 0.9)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 15, -15)

local authorText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
authorText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
authorText:SetTextColor(1, 1, 1, 1)
authorText:SetText("by Revinder")

local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusText:SetText("")

local statusTimer
function addon.SetStatus(text, isError)
	if isError then
		statusText:SetTextColor(1, 0.3, 0.3)
	else
		statusText:SetTextColor(0.3, 1, 0.3)
	end
	statusText:SetText(text)
	if statusTimer then
		statusTimer:Cancel()
	end
	statusTimer = C_Timer.NewTimer(3.5, function()
		statusText:SetText("")
	end)
end

local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -5, -5)

-------------------------------------------------------------------------------
-- Reset Outfit button
-------------------------------------------------------------------------------
local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
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
		addon.SetStatus("Outfit reset command sent!", false)
	else
		addon.SetStatus("Error: Chat frame not found.", true)
	end
	addon.UnfocusAll()
end)

-------------------------------------------------------------------------------
-- Search bar
-------------------------------------------------------------------------------
local searchContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
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

local searchBox = CreateFrame("EditBox", nil, searchContainer)
searchBox:SetAllPoints(searchContainer)
searchBox:SetTextInsets(8, 8, 0, 0)
searchBox:SetFontObject("GameFontHighlight")
searchBox:SetAutoFocus(false)
searchBox:SetMultiLine(false)
addon.RegisterEditBox(searchBox)

local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
searchPlaceholder:SetText("Search...")

searchBox:SetScript("OnTextChanged", function(self)
	if self:GetText() == "" then
		searchPlaceholder:Show()
	else
		searchPlaceholder:Hide()
	end
	addon.RefreshList()
end)
searchBox:SetScript("OnEscapePressed", function(self)
	self:ClearFocus()
end)

-------------------------------------------------------------------------------
-- Outfit list panel + scroll
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
-- Layout menu + dynamic grid resizer
-------------------------------------------------------------------------------
local layoutBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
layoutBtn:SetPoint("LEFT", searchContainer, "RIGHT", 5, 0)

local layoutMenu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
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

function addon.SetGridLayout(cols)
	local db = addon.DB
	db.columnLayout = cols
	layoutBtn:SetText("Size: " .. layouts[cols].name)
	layoutMenu:Hide()

	if cols == 1 then
		title:SetFontObject("GameFontNormal")
		title:SetText("iMorph Outfits")
		resetBtn:ClearAllPoints()
		resetBtn:SetSize(82, 20)
		resetBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -13)
		searchContainer:SetWidth(75)
		layoutBtn:SetSize(105, 24)
	else
		title:SetFontObject("GameFontNormalLarge")
		title:SetText("iMorph Outfits")
		resetBtn:ClearAllPoints()
		resetBtn:SetSize(100, 22)
		resetBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -38, -14)
		searchContainer:SetWidth(120)
		layoutBtn:SetSize(140, 24)
	end

	layoutMenu:SetWidth(layoutBtn:GetWidth())
	for i, mBtn in ipairs(layoutMenu.buttons) do
		mBtn:ClearAllPoints()
		mBtn:SetSize(layoutBtn:GetWidth() - 10, 22)
		mBtn:SetPoint("TOPLEFT", 5, -5 - ((i - 1) * 24))
	end

	local contentWidth = (cols * BTN_WIDTH) + ((cols - 1) * X_SPACING)
	local insetWidth = contentWidth + 30
	listInset:SetWidth(insetWidth)
	scrollContent:SetWidth(contentWidth)

	local topControlsMinWidth = math.max(searchContainer:GetWidth() + 5 + layoutBtn:GetWidth() + 30, 315)
	local finalFrameWidth = math.max(topControlsMinWidth, insetWidth + 30)
	frame:SetWidth(finalFrameWidth)

	addon.RefreshList()
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
		addon.SetGridLayout(opt.cols)
	end)
	table.insert(layoutMenu.buttons, mBtn)
end

-------------------------------------------------------------------------------
-- Bottom action bar
-------------------------------------------------------------------------------
local newOutfitBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
newOutfitBtn:SetSize(80, 22)
newOutfitBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, 14)
newOutfitBtn:SetText("New Outfit")
newOutfitBtn:SetScript("OnClick", function()
	addon.OpenEditor(nil)
end)

local exportBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
exportBtn:SetSize(52, 22)
exportBtn:SetPoint("LEFT", newOutfitBtn, "RIGHT", 4, 0)
exportBtn:SetText("Export")
exportBtn:SetScript("OnClick", function()
	addon.OpenExport()
end)

local importBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
importBtn:SetSize(52, 22)
importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 4, 0)
importBtn:SetText("Import")
importBtn:SetScript("OnClick", function()
	addon.OpenImport()
end)

local deleteAllBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
deleteAllBtn:SetSize(72, 22)
deleteAllBtn:SetPoint("LEFT", importBtn, "RIGHT", 4, 0)
deleteAllBtn:SetText("Delete All")

statusText:SetPoint("BOTTOMLEFT", deleteAllBtn, "BOTTOMRIGHT", 10, 4)

-------------------------------------------------------------------------------
-- Delete All (confirmation, in-place wipe preserving settings)
-------------------------------------------------------------------------------
local isDeleteAllConfirming = false
local deleteAllTimer
deleteAllBtn:SetScript("OnClick", function(self)
	if not isDeleteAllConfirming then
		isDeleteAllConfirming = true
		self:SetText("Confirm?")
		addon.SetStatus("Click again to clear ALL outfits!", true)
		deleteAllTimer = C_Timer.NewTimer(4.0, function()
			isDeleteAllConfirming = false
			self:SetText("Delete All")
		end)
	else
		if deleteAllTimer then
			deleteAllTimer:Cancel()
		end
		isDeleteAllConfirming = false
		self:SetText("Delete All")

		-- Wipe in place: clear only the array part so the table reference is
		-- preserved (addon.DB stays valid) and settings are kept.
		local db = addon.DB
		for i = #db, 1, -1 do
			db[i] = nil
		end
		db.columnLayout = db.columnLayout or 1
		db.minimapPos = db.minimapPos or 45

		addon.editIndex = nil
		if addon.editDialog then
			addon.editDialog:Hide()
		end
		addon.SetStatus("All wardrobe entries purged.", true)
		addon.RefreshList()
	end
end)

-------------------------------------------------------------------------------
-- Outfit grid (button pool with permanent scripts)
-------------------------------------------------------------------------------
local macroButtons = {}

local function CreateMacroButton(index)
	local btn = CreateFrame("Button", "IMO_MacroBtn_" .. index, scrollContent, "BackdropTemplate")
	btn:SetSize(BTN_WIDTH, BTN_HEIGHT)
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

	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	-- Permanent scripts: read live data from self.dbIndex / addon.DB.
	-- These closures are created exactly once per button, never per refresh.
	btn:SetScript("OnClick", function(self, button)
		local dbIndex = self.dbIndex
		local data = addon.DB[dbIndex]
		if not data then
			return
		end
		if button == "LeftButton" then
			if IsControlKeyDown() then
				table.remove(addon.DB, dbIndex)
				addon.SetStatus("Deleted: " .. (data.name or ""), true)
				-- Keep the editor's selectedIndex correct after removal.
				if addon.editIndex then
					if addon.editIndex == dbIndex then
						addon.CloseEditor()
						return
					elseif addon.editIndex > dbIndex then
						addon.editIndex = addon.editIndex - 1
					end
				end
				addon.RefreshList()
			else
				addon.ApplyOutfit(data)
				addon.SetStatus("Applied: " .. (data.name or ""), false)
			end
		elseif button == "RightButton" then
			addon.OpenEditor(dbIndex)
		end
	end)

	btn.starBtn:SetScript("OnClick", function(self)
		local dbIndex = self:GetParent().dbIndex
		local data = addon.DB[dbIndex]
		if data then
			data.isFavorite = not data.isFavorite
			addon.RefreshList()
		end
	end)

	btn:SetScript("OnEnter", function(self)
		local data = addon.DB[self.dbIndex]
		if not data then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(data.name or "", 1, 1, 1)
		if data.note and data.note ~= "" then
			GameTooltip:AddLine("\n|cff00ff00Outfit Note:|r\n" .. data.note, 1, 1, 1, true)
		else
			GameTooltip:AddLine("\n|cff888888No descriptions added.|r")
		end
		GameTooltip:AddLine(
			"\n|cffffaa00[Left-Click]|r Apply Outfit\n"
				.. "|cffffaa00[Ctrl+Left-Click]|r Instantly Delete\n"
				.. "|cffffaa00[Right-Click]|r Open Editor Dialog",
			0.7,
			0.7,
			0.7
		)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	return btn
end

-------------------------------------------------------------------------------
-- RefreshList - grid compiler
-------------------------------------------------------------------------------
function addon.RefreshList()
	local db = addon.DB
	local filterText = string.lower(searchBox:GetText() or "")
	local cols = db.columnLayout or 1

	-- Single pass: collect matches + favorite ranking.
	local matches = {}
	local favIndices = {}
	local favCount = 0
	for i, data in ipairs(db) do
		if type(data) == "table" then
			local name = data.name or ""
			if filterText == "" or string.find(string.lower(name), filterText, 1, true) then
				if data.isFavorite then
					favCount = favCount + 1
					favIndices[i] = favCount
				end
				matches[#matches + 1] = { dbIndex = i, isFav = data.isFavorite and 1 or 0 }
			end
		end
	end

	-- Favorites first, preserving original order via dbIndex tiebreaker.
	table.sort(matches, function(a, b)
		if a.isFav ~= b.isFav then
			return a.isFav > b.isFav
		end
		return a.dbIndex < b.dbIndex
	end)

	local editorShown = addon.editDialog and addon.editDialog:IsShown()

	for displayIndex, item in ipairs(matches) do
		local btn = macroButtons[displayIndex]
		if not btn then
			btn = CreateMacroButton(displayIndex)
			macroButtons[displayIndex] = btn
		end
		local data = db[item.dbIndex]
		btn.dbIndex = item.dbIndex

		local row = math.floor((displayIndex - 1) / cols)
		local col = (displayIndex - 1) % cols
		local xPos = col * (BTN_WIDTH + X_SPACING)
		local yPos = -row * (BTN_HEIGHT + Y_SPACING)
		btn:ClearAllPoints()
		btn:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", xPos, yPos)

		btn.text:SetText(data.name or "")

		if data.isFavorite then
			btn.starTex:SetVertexColor(1, 1, 1, 1)
			btn.favText:SetText("#" .. (favIndices[item.dbIndex] or ""))
			btn.favText:Show()
		else
			btn.starTex:SetVertexColor(0.25, 0.25, 0.25, 0.3)
			btn.favText:SetText("")
			btn.favText:Hide()
		end

		if editorShown and addon.editIndex == item.dbIndex then
			btn:SetBackdropColor(0.1, 0.4, 0.1, 0.8)
			btn:SetBackdropBorderColor(0, 1, 0, 1)
		else
			btn:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
			btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
		end

		btn:Show()
	end

	for i = #matches + 1, #macroButtons do
		if macroButtons[i] then
			macroButtons[i]:Hide()
		end
	end

	local totalRows = math.ceil(#matches / cols)
	scrollContent:SetHeight(math.max(1, totalRows * (BTN_HEIGHT + Y_SPACING)))
end

-------------------------------------------------------------------------------
-- Toggle + init
-------------------------------------------------------------------------------
function addon.ToggleMainFrame()
	if frame:IsShown() then
		frame:Hide()
		addon.CloseEditor()
		if addon.ioDialog then
			addon.ioDialog:Hide()
		end
	else
		frame:Show()
		addon.SetGridLayout(addon.DB.columnLayout or 1)
	end
end

addon.OnInit(function()
	addon.SetGridLayout(addon.DB.columnLayout or 1)
end)
