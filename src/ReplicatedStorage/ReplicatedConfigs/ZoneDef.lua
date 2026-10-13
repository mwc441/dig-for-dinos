local ZoneDef = {}

ZoneDef.Table = {
	["Zone1"] = {
		Name = "Grassland",
		Emoji = "🌱",
		Color = ColorSequence.new(Color3.fromHex("#c4ffbd"), Color3.fromHex("#48ff10"))
	},

	["Zone2"] = {
		Name = "Farm",
		Emoji = "🚜",
		Color = ColorSequence.new(Color3.fromHex("#ffcecf"), Color3.fromHex("#ff2f32"))
	},

	["Zone3"] = {
		Name = "Aztec",
		Emoji = "🗿",
		Color = ColorSequence.new(Color3.fromHex("#ffffff"), Color3.fromHex("#818181"))
	},

	["Zone4"] = {
		Name = "Desert",
		Emoji = "🐪",
		Color = ColorSequence.new(Color3.fromHex("#fdffcd"), Color3.fromHex("#ffbe63"))
	},

	["Zone5"] = {
		Name = "Snow",
		Emoji = "❄️",
		Color = ColorSequence.new(Color3.fromHex("#ffffff"), Color3.fromHex("#00ffff"))
	},

	["Zone6"] = {
		Name = "Volcano",
		Emoji = "🌋",
		Color = ColorSequence.new(Color3.fromHex("#ffef3d"), Color3.fromHex("#ff0000"))
	},

	["Zone7"] = {
		Name = "Fantasy",
		Emoji = "🍄",
		Color = ColorSequence.new(Color3.fromHex("#bfa2ff"), Color3.fromHex("#8e1dff"))
	}
}

function ZoneDef.GetZoneInfo(zoneId)
	return ZoneDef.Table[zoneId]
end

return ZoneDef