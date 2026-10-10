local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage:WaitForChild("Enums"):WaitForChild("Rarities"))

local DirtDef = {}

DirtDef.Ids = {
	Common = "CommonDirt",
	Uncommon = "UncommonDirt",
	Rare = "RareDirt",
	Epic = "EpicDirt",
	Legendary = "LegendaryDirt",
	Mythical = "MythicalDirt",
	SecretDirt = "SecretDirt"
}

DirtDef.Table = {
	[DirtDef.Ids.Common] = {
		Name = "Common Dirt",
		Rarity = Rarities.Common,
		TotalHealth = 100
	},
	[DirtDef.Ids.Uncommon] = {
		Name = "Uncommon Dirt",
		Rarity = Rarities.Uncommon,
		TotalHealth = 150
	},
	[DirtDef.Ids.Rare] = {
		Name = "Rare Dirt",
		Rarity = Rarities.Rare,
		TotalHealth = 250
	},
	[DirtDef.Ids.Epic] = {
		Name = "Epic Dirt",
		Rarity = Rarities.Epic,
		TotalHealth = 400
	},
	[DirtDef.Ids.Legendary] = {
		Name = "Legendary Dirt",
		Rarity = Rarities.Legendary,
		TotalHealth = 600
	},
	[DirtDef.Ids.Mythical] = {
		Name = "Mythical Dirt",
		Rarity = Rarities.Mythical,
		TotalHealth = 1000
	},
	[DirtDef.Ids.SecretDirt] = {
		Name = "Secret Dirt",
		Rarity = Rarities.Secret,
		TotalHealth = 2000
	}
}

function DirtDef.GetDirtInfo(dirtId)
	return DirtDef.Table[dirtId]
end

return DirtDef
