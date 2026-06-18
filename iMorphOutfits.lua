local addonName = "iMorphOutfits"

-- Globally initialized database for outfit configurations (Preserved)
iMorphOutfitsDB = iMorphOutfitsDB or {}

local frame = CreateFrame("Frame", "IMO_MainFrame", UIParent, "BackdropTemplate")
frame:SetSize(530, 450)
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
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
frame:SetBackdropColor(0, 0, 0, 0.9)

-- Title Heading (iMorph Outfits)
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 15, -15)
title:SetText("iMorph Outfits")

-- Author Credit Subtitle
local authorText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
authorText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
authorText:SetTextColor(1, 1, 1, 1) -- Pure White
authorText:SetText("by Revinder")

-- Status Message Display String (Bottom Center Alignment)
local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 12)
statusText:SetText("")

local statusTimer
local function SetStatus(text, isError)
    if isError then
        statusText:SetTextColor(1, 0.3, 0.3) -- Warning Red
    else
        statusText:SetTextColor(0.3, 1, 0.3) -- Success Green
    end
    statusText:SetText(text)
    
    if statusTimer then statusTimer:Cancel() end
    statusTimer = C_Timer.NewTimer(3.5, function() statusText:SetText("") end)
end

-- Close Button
local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -5, -5)

-- Forward declaration for the search box
local searchBox

-- Releases keyboard traps entirely so WASD functions right away
local function UnfocusAllInputBoxes()
    if nameInput then nameInput:ClearFocus() end
    if textInput then textInput:ClearFocus() end
    if noteInput then noteInput:ClearFocus() end
    if searchBox then searchBox:ClearFocus() end
end

-- Shared Core Outfit Executor Engine
local function ApplyOutfit(data)
    if not data or not data.body or data.body == "" then return end
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

-- Top Right "Reset Outfit" Button Configuration
local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
resetBtn:SetSize(100, 22)
resetBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -38, -14)
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

-------------------------------------------------------------------------------
-- DYNAMIC SEARCH BAR (Width: 200)
-------------------------------------------------------------------------------
local searchContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
searchContainer:SetSize(200, 24)
searchContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -52)
searchContainer:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
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
searchPlaceholder:SetText("Search outfits...")

searchBox:SetScript("OnTextChanged", function(self)
    if self:GetText() == "" then
        searchPlaceholder:Show()
    else
        searchPlaceholder:Hide()
    end
    if RefreshMacroList then RefreshMacroList() end
end)
searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

-------------------------------------------------------------------------------
-- LEFT COLUMN: OUTFIT LIST PANEL
-------------------------------------------------------------------------------
local listInset = CreateFrame("Frame", nil, frame, "BackdropTemplate")
listInset:SetSize(200, 332)
listInset:SetPoint("TOPLEFT", 15, -82)
listInset:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
listInset:SetBackdropColor(0.05, 0.05, 0.05, 0.7)

local scrollFrame = CreateFrame("ScrollFrame", "IMO_ScrollFrame", listInset, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 5, -5)
scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)

scrollFrame:EnableMouseWheel(true)
scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local current = self:GetVerticalScroll()
    local new = current - (delta * 25)
    if new < 0 then new = 0 end
    local maxScroll = self:GetVerticalScrollRange()
    if new > maxScroll then new = maxScroll end
    self:SetVerticalScroll(new)
end)

local scrollContent = CreateFrame("Frame", "IMO_ScrollContent", scrollFrame)
scrollContent:SetSize(170, 1)
scrollFrame:SetScrollChild(scrollContent)

-------------------------------------------------------------------------------
-- RIGHT COLUMN: EDITOR INPUTS WITH SCROLL WRAPPING (Width: 280)
-------------------------------------------------------------------------------
local function CreateLabelAndEditBox(labelName, yOffset, height, multiLine)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 235, yOffset)
    label:SetText(labelName)
    
    local ebContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    ebContainer:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    ebContainer:SetSize(280, height)
    ebContainer:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
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
        
        eb:SetScript("OnTextChanged", function(self)
            sFrame:UpdateScrollChildRect()
        end)
        
        eb:SetScript("OnCursorChanged", function(self, x, y, w, h)
            sFrame:UpdateScrollChildRect()
            local scrollRange = sFrame:GetVerticalScrollRange()
            if scrollRange > 0 then
                local currentScroll = sFrame:GetVerticalScroll()
                if -y > (currentScroll + height - 24) then
                    sFrame:SetVerticalScroll(-y - (height - 24))
                elseif -y < currentScroll then
                    sFrame:SetVerticalScroll(-y)
                end
            end
        end)
        
        ebContainer:SetScript("OnMouseDown", function() eb:SetFocus() end)
    else
        eb = CreateFrame("EditBox", nil, ebContainer)
        eb:SetAllPoints(ebContainer)
        eb:SetTextInsets(8, 8, 8, 8)
        eb:SetFontObject("GameFontHighlight")
        eb:SetAutoFocus(false)
        eb:SetMultiLine(false)
    end
    
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return eb
end

nameInput = CreateLabelAndEditBox("Outfit Name:", -60, 26, false)
textInput = CreateLabelAndEditBox("Macro Body (Commands):", -115, 130, true)
noteInput = CreateLabelAndEditBox("Note / Explanation:", -275, 90, true)

-- Action Buttons (Bottom Right)
local saveBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
saveBtn:SetSize(90, 26)
saveBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 235, -395)
saveBtn:SetText("Save New")

local deleteBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
deleteBtn:SetSize(90, 26)
deleteBtn:SetPoint("LEFT", saveBtn, "RIGHT", 5, 0)
deleteBtn:SetText("Delete")
deleteBtn:Disable()

local clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
clearBtn:SetSize(90, 26)
clearBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 5, 0)
clearBtn:SetText("Clear / New")

-------------------------------------------------------------------------------
-- CORE LOGIC, SEARCH ENGINE & FAVORITES SYSTEM
-------------------------------------------------------------------------------
local macroButtons = {}
local selectedIndex = nil

function RefreshMacroList()
    local yOffset = 0
    local displayIndex = 1
    local filterText = string.lower(searchBox:GetText() or "")

    local favCount = 0
    local favIndices = {}
    for i, data in ipairs(iMorphOutfitsDB) do
        if data.isFavorite then
            favCount = favCount + 1
            favIndices[i] = favCount
        end
    end

    for i, data in ipairs(iMorphOutfitsDB) do
        if filterText == "" or string.find(string.lower(data.name or ""), filterText, 1, true) then
            local btn = macroButtons[displayIndex]
            if not btn then
                btn = CreateFrame("Button", "IMO_MacroBtn_"..displayIndex, scrollContent, "BackdropTemplate")
                btn:SetSize(165, 30)
                btn:SetBackdrop({
                    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 12,
                    insets = { left = 3, right = 3, top = 3, bottom = 3 }
                })
                
                btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                btn.text:SetPoint("LEFT", 10, 0)
                btn.text:SetPoint("RIGHT", -50, 0)
                btn.text:SetJustifyH("LEFT")
                
                btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                macroButtons[displayIndex] = btn
            end
            
            if not btn.starBtn then
                btn.starBtn = CreateFrame("Button", nil, btn)
                btn.starBtn:SetSize(14, 14)
                btn.starBtn:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
                
                btn.starTex = btn.starBtn:CreateTexture(nil, "ARTWORK")
                btn.starTex:SetAllPoints()
                btn.starTex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
                btn.starTex:SetTexCoord(0, 0.25, 0, 0.25)
                
                btn.favText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                btn.favText:SetPoint("RIGHT", btn.starBtn, "LEFT", -2, 0)
                btn.favText:SetTextColor(1, 0.82, 0)
                
                btn.starBtn:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Favorite Status", 1, 1, 1)
                    GameTooltip:AddLine("Click to toggle favoriting this configuration.", 0.7, 0.7, 0.7)
                    GameTooltip:Show()
                end)
                btn.starBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
            
            btn.starBtn:SetScript("OnClick", function()
                iMorphOutfitsDB[i].isFavorite = not iMorphOutfitsDB[i].isFavorite
                if iMorphOutfitsDB[i].isFavorite then
                    SetStatus(data.name .. " added to favorites!", false)
                else
                    SetStatus(data.name .. " removed from favorites.", true)
                end
                RefreshMacroList()
            end)
            
            btn:SetPoint("TOPLEFT", 0, yOffset)
            btn.text:SetText(data.name)
            
            if data.isFavorite then
                btn.starTex:SetVertexColor(1, 1, 1, 1)
                btn.favText:SetText("#" .. (favIndices[i] or ""))
                btn.favText:Show()
            else
                btn.starTex:SetVertexColor(0.25, 0.25, 0.25, 0.35)
                btn.favText:SetText("")
                btn.favText:Hide()
            end
            
            if selectedIndex == i then
                btn:SetBackdropColor(0.1, 0.4, 0.1, 0.8)
                btn:SetBackdropBorderColor(0, 1, 0, 1)
            else
                btn:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
                btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
            end
            
            btn:SetScript("OnClick", function(self, button)
                if button == "LeftButton" then
                    ApplyOutfit(data)
                elseif button == "RightButton" then
                    selectedIndex = i
                    nameInput:SetText(data.name)
                    textInput:SetText(data.body)
                    noteInput:SetText(data.note or "")
                    saveBtn:SetText("Update")
                    deleteBtn:Enable()
                    RefreshMacroList()
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
                GameTooltip:AddLine("\n|cffffaa00[Left-Click]|r Apply Outfit\n|cffffaa00[Right-Click]|r Edit Settings", 0.7, 0.7, 0.7)
                GameTooltip:Show()
            end)
            
            btn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
            btn:Show()
            yOffset = yOffset - 34
            displayIndex = displayIndex + 1
        end
    end
    
    for i = displayIndex, #macroButtons do
        if macroButtons[i] then macroButtons[i]:Hide() end
    end
    
    scrollContent:SetHeight(math.abs(yOffset))
end

local function ToggleMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        RefreshMacroList()
    end
end

local function ClearEditor()
    nameInput:SetText("")
    textInput:SetText("")
    noteInput:SetText("")
    selectedIndex = nil
    saveBtn:SetText("Save New")
    deleteBtn:Disable()
    RefreshMacroList()
end

saveBtn:SetScript("OnClick", function()
    local name = nameInput:GetText()
    local body = textInput:GetText()
    local note = noteInput:GetText()
    
    if name == "" or body == "" then 
        SetStatus("Outfit wasn't saved. Name and Commands required!", true)
        UnfocusAllInputBoxes()
        return 
    end
    
    if selectedIndex then
        local wasFavorite = iMorphOutfitsDB[selectedIndex].isFavorite
        iMorphOutfitsDB[selectedIndex] = { name = name, body = body, note = note, isFavorite = wasFavorite }
        SetStatus("Outfit updated successfully!", false)
        RefreshMacroList()
    else
        table.insert(iMorphOutfitsDB, { name = name, body = body, note = note })
        SetStatus("Outfit saved successfully!", false)
        ClearEditor()
    end
    UnfocusAllInputBoxes()
end)

deleteBtn:SetScript("OnClick", function()
    if selectedIndex then
        table.remove(iMorphOutfitsDB, selectedIndex)
        SetStatus("Outfit layout deleted.", true)
        ClearEditor()
        UnfocusAllInputBoxes()
    end
end)

clearBtn:SetScript("OnClick", function()
    ClearEditor()
    UnfocusAllInputBoxes()
end)

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
    GameTooltip:AddLine("\n|cffffaa00[Left-Click]|r Toggle Wardrobe Frame\n|cffffaa00[Drag Button]|r Reposition Around Minimap", 1, 1, 1, true)
    GameTooltip:Show()
end)
miniButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-------------------------------------------------------------------------------
-- INITIALIZATION ENGINE & SLASH ROUTING
-------------------------------------------------------------------------------
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and string.lower(arg1) == string.lower(addonName) then
        iMorphOutfitsDB = iMorphOutfitsDB or {}
        if not iMorphOutfitsDB.minimapPos then iMorphOutfitsDB.minimapPos = 45 end
        RepositionMinimapButton()
        RefreshMacroList()
    end
end)

SLASH_IMORPHOUTFITS1 = "/imo"
SLASH_IMORPHOUTFITS2 = "/rev"

SlashCmdList["IMORPHOUTFITS"] = function(msg)
    -- Normalize and sanitize text input string mapping parameters safely
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
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00/rev random|r - Actively chooses one layout out of all saved options at random")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00/rev favourite list|r - Outputs sequential catalog indexing numbers and associated names")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00/rev favourite random|r - Picks one profile strictly isolated within favored definitions")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00/rev favourite <number>|r - Fires the exact specified favorite profile assignment path")
        return
        
    elseif cmd == "random" then
        if #iMorphOutfitsDB == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff3333iMorph Outfits Error: You do not have any configurations stored yet!|r")
            return
        end
        local randomIndex = math.random(1, #iMorphOutfitsDB)
        local data = iMorphOutfitsDB[randomIndex]
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00iMorph Outfits:|r Random selection chosen: |cffffaa00" .. data.name .. "|r")
        ApplyOutfit(data)
        return
        
    elseif cmd == "favourite" or cmd == "favorite" then
        if arg == "list" then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00iMorph Outfits - Active Favorites Catalog:|r")
            local listCount = 0
            for _, data in ipairs(iMorphOutfitsDB) do
                if data.isFavorite then
                    listCount = listCount + 1
                    DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00#" .. listCount .. "|r: " .. data.name)
                end
            end
            if listCount == 0 then
                DEFAULT_CHAT_FRAME:AddMessage("  |cff888888No profiles have been designated favorite bookmarks yet.|r")
            end
            return
            
        elseif arg == "random" then
            local favEntries = {}
            for _, data in ipairs(iMorphOutfitsDB) do
                if data.isFavorite then
                    table.insert(favEntries, data)
                end
            end
            if #favEntries == 0 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff3333iMorph Outfits Error: You do not have any profiles favorited yet!|r")
                return
            end
            local randomFavIndex = math.random(1, #favEntries)
            local data = favEntries[randomFavIndex]
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00iMorph Outfits:|r Random favorite chosen: |cffffaa00" .. data.name .. "|r")
            ApplyOutfit(data)
            return
            
        else
            local conversionNumber = tonumber(arg)
            if conversionNumber then
                local calculationCounter = 0
                for _, data in ipairs(iMorphOutfitsDB) do
                    if data.isFavorite then
                        calculationCounter = calculationCounter + 1
                        if calculationCounter == conversionNumber then
                            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00iMorph Outfits:|r Executing favorite #" .. conversionNumber .. ": |cffffaa00" .. data.name .. "|r")
                            ApplyOutfit(data)
                            return
                        end
                    end
                end
                DEFAULT_CHAT_FRAME:AddMessage("|cffff3333iMorph Outfits Error: Favorite layout #" .. conversionNumber .. " does not exist!|r")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cffff3333iMorph Outfits Error: Invalid structural command parameter. Type /rev help.|r")
            end
            return
        end
    else
        ToggleMainFrame()
    end
end