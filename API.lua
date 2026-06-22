-------------------------------------------------------------------------------
-- iMorph Outfits - API
-- Chat execution engine + import/export serialization.
-- Export uses a compact escape codec (see below) instead of per-byte hex,
-- and outfit execution hoists the chat-editbox backup/restore outside the
-- per-line loop.
-------------------------------------------------------------------------------

local addon = iMorphOutfits
local string = string
local ChatEdit_SendText = ChatEdit_SendText

-------------------------------------------------------------------------------
-- Import / Export codec
--
-- Compact escape-based encoding (format tag "v2:"). Printable ASCII passes
-- through literally; only the format-breaking characters (\, \n, \r, :, ;) and
-- other control/high bytes are escaped. For typical iMorph macro text this is
-- roughly 2x smaller than the old per-byte hex encoding.
--
-- Escape table (backslash-prefixed):
--   \\  -> backslash       \n  -> newline (CR normalized to LF)
--   \c  -> ':'             \s  -> ';'
--   \xHH -> raw byte (control chars / non-ASCII, e.g. UTF-8)
--
-- Old hex-encoded exports (no "v2:" prefix) are still decoded for backward
-- compatibility, so previously exported strings keep importing fine.
-------------------------------------------------------------------------------

-- Lazily-filled 2-hex -> byte cache. Bounded to at most 256 entries total.
addon._hexDecodeTable = setmetatable({}, {
	__index = function(t, key)
		local v = string.char(tonumber(key, 16))
		t[key] = v
		return v
	end,
})

-- Single-char escape map (table replacement -> zero per-char closures).
local ESCAPE_MAP = {
	["\\"] = "\\\\",  -- \  -> \\
	["\n"] = "\\n",   -- LF -> \n
	["\r"] = "\\n",   -- CR -> \n (normalize)
	[":"] = "\\c",    -- :  -> \c
	[";"] = "\\s",    -- ;  -> \s
}

local function escapeField(str)
	-- First pass: fixed single-char escapes via table replacement (fast).
	str = string.gsub(str, "[\\\r\n:;]", ESCAPE_MAP)
	-- Second pass: remaining control bytes, DEL and non-ASCII -> \xHH.
	-- Runs only on the rare bytes that slip through, so the closure is rare.
	str = string.gsub(str, "[%z\1-\8\11-\31\127-\255]", function(c)
		return string.format("\\x%02X", string.byte(c))
	end)
	return str
end

-- Reverse of the single-char escapes. Table keyed by the captured character.
local SINGLE_UNESCAPE = {
	["\\"] = "\\",
	["n"] = "\n",
	["c"] = ":",
	["s"] = ";",
}

local function unescapeField(str)
	-- Single-char escapes first. \x.. sequences are left untouched here because
	-- 'x' is not in [\\ncs], so they survive to the second pass intact.
	str = string.gsub(str, "\\([\\ncs])", SINGLE_UNESCAPE)
	-- Then \xHH -> raw byte. Produced bytes are final (no re-processing).
	str = string.gsub(str, "\\x(%x%x)", addon._hexDecodeTable)
	return str
end

-- Legacy per-byte hex decoder (for exports made before v1.2).
local function legacyHexDecode(hex)
	return (string.gsub(hex, "(%x%x)", addon._hexDecodeTable))
end

-------------------------------------------------------------------------------
-- Outfit execution
-------------------------------------------------------------------------------
function addon.ApplyOutfit(data)
	if not data or not data.body or data.body == "" then
		return
	end
	local editBox = ChatFrame1EditBox
	if not editBox then
		return
	end

	-- Hoist backup/restore outside the loop: only one set of chatType/text
	-- round-trips per outfit instead of one per line.
	local backupChatType = editBox:GetAttribute("chatType")
	local backupText = editBox:GetText()
	editBox:SetAttribute("chatType", "SAY")

	for line in string.gmatch(data.body, "[^\r\n]+") do
		line = string.gsub(line, "^%s*(.-)%s*$", "%1")
		if line ~= "" then
			editBox:SetText(line)
			ChatEdit_SendText(editBox, 0)
		end
	end

	editBox:SetText(backupText)
	editBox:SetAttribute("chatType", backupChatType)
end

-------------------------------------------------------------------------------
-- Import / Export serialization
-------------------------------------------------------------------------------
local FORMAT_PREFIX = "v2:"

function addon.EncodeOutfits()
	local pieces = {}
	for _, outfit in ipairs(addon.DB) do
		local name = escapeField(outfit.name or "")
		local body = escapeField(outfit.body or "")
		local note = escapeField(outfit.note or "")
		local isFav = outfit.isFavorite and "1" or "0"
		pieces[#pieces + 1] = name .. ":" .. body .. ":" .. note .. ":" .. isFav
	end
	return FORMAT_PREFIX .. table.concat(pieces, ";")
end

function addon.DecodeOutfits(str)
	local db = addon.DB

	-- Pick the codec by format tag. Old hex exports have no prefix.
	local decode
	if string.sub(str, 1, #FORMAT_PREFIX) == FORMAT_PREFIX then
		str = string.sub(str, #FORMAT_PREFIX + 1)
		decode = unescapeField
	else
		decode = legacyHexDecode
	end

	local function NameExists(name)
		for _, outfit in ipairs(db) do
			if outfit.name == name then
				return true
			end
		end
		return false
	end

	local count = 0
	for outfitStr in string.gmatch(str, "[^;]+") do
		local nameEnc, bodyEnc, noteEnc, isFav =
			string.match(outfitStr, "^([^:]*):([^:]*):([^:]*):(%d)$")
		if nameEnc and bodyEnc then
			local name = decode(nameEnc)
			local body = decode(bodyEnc)
			local note = decode(noteEnc)
			if name ~= "" and body ~= "" then
				if NameExists(name) then
					local suffixNum = 1
					local baseName = name
					while NameExists(baseName .. "[imported-" .. suffixNum .. "]") do
						suffixNum = suffixNum + 1
					end
					name = baseName .. "[imported-" .. suffixNum .. "]"
				end
				db[#db + 1] = {
					name = name,
					body = body,
					note = note ~= "" and note or nil,
					isFavorite = (isFav == "1"),
				}
				count = count + 1
			end
		end
	end
	return count
end
