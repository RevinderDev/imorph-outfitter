-------------------------------------------------------------------------------
-- iMorph Outfits - Core
-- Namespace, SavedVariables management and shared helpers.
--
-- IMPORTANT (data safety): the global `iMorphOutfitsDB` is the SavedVariables
-- table populated by the client. We NEVER reassign it - every module mutates
-- it in place - so cached references (addon.DB) stay valid across the whole
-- session, including after "Delete All". Existing user outfits are preserved.
-------------------------------------------------------------------------------

local addonName = ...
local addon = {}
_G[addonName] = addon

-- SavedVariables global. The client has already restored this by the time our
-- code runs; the `or {}` only kicks in for a brand-new install.
iMorphOutfitsDB = iMorphOutfitsDB or {}
addon.DB = iMorphOutfitsDB
addon.addonName = addonName

-------------------------------------------------------------------------------
-- Registered edit boxes - used by the global "unfocus all" helper.
-------------------------------------------------------------------------------
local editboxes = {}
function addon.RegisterEditBox(eb)
	editboxes[#editboxes + 1] = eb
end
function addon.UnfocusAll()
	for i = 1, #editboxes do
		editboxes[i]:ClearFocus()
	end
end

-------------------------------------------------------------------------------
-- Init callback registry.
-- Modules register setup work that must run after SavedVariables are confirmed
-- loaded (ADDON_LOADED). This removes all the old forward-declaration hacks.
-------------------------------------------------------------------------------
local initCallbacks = {}
function addon.OnInit(fn)
	initCallbacks[#initCallbacks + 1] = fn
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
	if event ~= "ADDON_LOADED" then
		return
	end
	if strlower(arg1) ~= strlower(addonName) then
		return
	end
	self:UnregisterEvent("ADDON_LOADED")

	-- Re-sync the DB reference (never reassign the global).
	addon.DB = iMorphOutfitsDB
	local db = addon.DB
	db.columnLayout = db.columnLayout or 1
	db.minimapPos = db.minimapPos or 45

	for i = 1, #initCallbacks do
		initCallbacks[i]()
	end
end)
