-------------------------------------------------------------------------------
-- iMorph Outfits - Slash command routing
-------------------------------------------------------------------------------

local addon = iMorphOutfits

SLASH_IMORPHOUTFITS1 = "/imo"
SLASH_IMORPHOUTFITS2 = "/rev"

SlashCmdList["IMORPHOUTFITS"] = function(msg)
	msg = string.lower(string.gsub(msg, "^%s*(.-)%s*$", "%1"))
	if msg == "" then
		addon.ToggleMainFrame()
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
		local db = addon.DB
		if #db == 0 then
			return
		end
		local rIdx = math.random(1, #db)
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00iMorph Outfits:|r Random: |cffffaa00" .. db[rIdx].name .. "|r")
		addon.ApplyOutfit(db[rIdx])
		return

	elseif cmd == "favourite" or cmd == "favorite" then
		local db = addon.DB
		if arg == "list" then
			DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00iMorph Outfits - Active Favorites Catalog:|r")
			local listCount = 0
			for _, d in ipairs(db) do
				if d.isFavorite then
					listCount = listCount + 1
					DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00#" .. listCount .. "|r: " .. d.name)
				end
			end
			return
		elseif arg == "random" then
			local favs = {}
			for _, d in ipairs(db) do
				if d.isFavorite then
					favs[#favs + 1] = d
				end
			end
			if #favs == 0 then
				return
			end
			local rIdx = math.random(1, #favs)
			DEFAULT_CHAT_FRAME:AddMessage(
				"|cff00ff00iMorph Outfits:|r Random Favorite: |cffffaa00" .. favs[rIdx].name .. "|r"
			)
			addon.ApplyOutfit(favs[rIdx])
			return
		else
			local num = tonumber(arg)
			if num then
				local count = 0
				for _, d in ipairs(db) do
					if d.isFavorite then
						count = count + 1
						if count == num then
							DEFAULT_CHAT_FRAME:AddMessage(
								"|cff00ff00iMorph Outfits:|r Favorite #" .. num .. ": |cffffaa00" .. d.name .. "|r"
							)
							addon.ApplyOutfit(d)
							return
						end
					end
				end
				DEFAULT_CHAT_FRAME:AddMessage("|cffff3333iMorph Outfits Error: Favorite #" .. num .. " not found!|r")
			end
			return
		end
	else
		addon.ToggleMainFrame()
	end
end
