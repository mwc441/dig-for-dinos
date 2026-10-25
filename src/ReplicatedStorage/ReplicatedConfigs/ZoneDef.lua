local ZoneDef = {}

-- IncomeMultiplier is just a lil bonus for going deeper INSIDE a set (1 / 2 / 4), nothing crazy
-- the big jump between sets is in DinosaurDef in each dinos base Income, go look there not here

ZoneDef.Table = {
	["Zone1"] = {
		Order = 1,
		Name = "Grassland",
		IncomeMultiplier = 1,
		Emoji = "🌱",
		Color = ColorSequence.new(Color3.fromHex("#c4ffbd"), Color3.fromHex("#48ff10")),
	},

	["Zone2"] = {
		Order = 2,
		Name = "Farm",
		IncomeMultiplier = 2,
		Emoji = "🚜",
		Color = ColorSequence.new(Color3.fromHex("#ffcecf"), Color3.fromHex("#ff2f32")),
	},

	["Zone3"] = {
		Order = 3,
		Name = "Aztec",
		IncomeMultiplier = 4,
		Emoji = "🗿",
		Color = ColorSequence.new(Color3.fromHex("#ffffff"), Color3.fromHex("#818181")),
	},

	["Zone4"] = {
		Order = 4,
		Name = "Desert",
		IncomeMultiplier = 1,
		Emoji = "🐪",
		Color = ColorSequence.new(Color3.fromHex("#fdffcd"), Color3.fromHex("#ffbe63")),
	},

	["Zone5"] = {
		Order = 5,
		Name = "Snow",
		IncomeMultiplier = 2,
		Emoji = "❄️",
		Color = ColorSequence.new(Color3.fromHex("#ffffff"), Color3.fromHex("#00ffff")),
	},

	["Zone6"] = {
		Order = 6,
		Name = "Volcano",
		IncomeMultiplier = 4,
		Emoji = "🌋",
		Color = ColorSequence.new(Color3.fromHex("#ffef3d"), Color3.fromHex("#ff0000")),
	},

	["Zone7"] = {
		Order = 7,
		Name = "Fantasy",
		IncomeMultiplier = 1,
		Emoji = "🍄",
		Color = ColorSequence.new(Color3.fromHex("#bfa2ff"), Color3.fromHex("#8e1dff")),
	},
}

function ZoneDef.GetZoneInfo(zoneId)
	return ZoneDef.Table[zoneId]
end

return ZoneDef
