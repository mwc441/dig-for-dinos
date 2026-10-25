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
	SecretDirt = "SecretDirt",
}

-- Weights are relative; each dirt rolls a dinosaur rarity before selecting a dinosaur from its zone.
-- every pile rolls its own rarity or higher. each step up is way rarer: 70 / 22 / 6 / 1.5 / 0.4 / 0.09 / 0.01. gambling baby
-- top piles are capped so secrets dont get fuckin handed out: legendary piles 3% secret, mythical piles 10% secret
-- this health gets multiplied by the zone's HealthMultiplier in DirtSpawnerDef, so dont freak out at the small numbers
DirtDef.Table = {
	[DirtDef.Ids.Common] = {
		Name = "Common Dirt",
		Rarity = Rarities.Common,
		TotalHealth = 100,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Common, Weight = 70 },
			{ Id = Rarities.Uncommon, Weight = 22 },
			{ Id = Rarities.Rare, Weight = 6 },
			{ Id = Rarities.Epic, Weight = 1.5 },
			{ Id = Rarities.Legendary, Weight = 0.4 },
			{ Id = Rarities.Mythical, Weight = 0.09 },
			{ Id = Rarities.Secret, Weight = 0.01 },
		},
	},
	[DirtDef.Ids.Uncommon] = {
		Name = "Uncommon Dirt",
		Rarity = Rarities.Uncommon,
		TotalHealth = 150,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Uncommon, Weight = 70 },
			{ Id = Rarities.Rare, Weight = 22 },
			{ Id = Rarities.Epic, Weight = 6 },
			{ Id = Rarities.Legendary, Weight = 1.5 },
			{ Id = Rarities.Mythical, Weight = 0.4 },
			{ Id = Rarities.Secret, Weight = 0.09 },
		},
	},
	[DirtDef.Ids.Rare] = {
		Name = "Rare Dirt",
		Rarity = Rarities.Rare,
		TotalHealth = 250,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Rare, Weight = 70 },
			{ Id = Rarities.Epic, Weight = 22 },
			{ Id = Rarities.Legendary, Weight = 6 },
			{ Id = Rarities.Mythical, Weight = 1.5 },
			{ Id = Rarities.Secret, Weight = 0.4 },
		},
	},
	[DirtDef.Ids.Epic] = {
		Name = "Epic Dirt",
		Rarity = Rarities.Epic,
		TotalHealth = 400,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Epic, Weight = 70.5 },
			{ Id = Rarities.Legendary, Weight = 22 },
			{ Id = Rarities.Mythical, Weight = 6 },
			{ Id = Rarities.Secret, Weight = 1.5 },
		},
	},
	[DirtDef.Ids.Legendary] = {
		Name = "Legendary Dirt",
		Rarity = Rarities.Legendary,
		TotalHealth = 650,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Legendary, Weight = 75 },
			{ Id = Rarities.Mythical, Weight = 22 },
			{ Id = Rarities.Secret, Weight = 3 },
		},
	},
	[DirtDef.Ids.Mythical] = {
		Name = "Mythical Dirt",
		Rarity = Rarities.Mythical,
		TotalHealth = 1_100,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Mythical, Weight = 90 },
			{ Id = Rarities.Secret, Weight = 10 },
		},
	},
	[DirtDef.Ids.SecretDirt] = {
		Name = "Secret Dirt",
		Rarity = Rarities.Secret,
		TotalHealth = 8_000,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Secret, Weight = 100 },
		},
	},
}

function DirtDef.GetDirtInfo(dirtId)
	return DirtDef.Table[dirtId]
end

return DirtDef
