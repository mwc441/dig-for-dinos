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

-- Weights are relative; each dirt rolls a dinosaur rarity before selecting a dinosaur from its zone.
DirtDef.Table = {
	[DirtDef.Ids.Common] = {
		Name = "Common Dirt",
		Rarity = Rarities.Common,
		TotalHealth = 100,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Common, Weight = 70 },
			{ Id = Rarities.Uncommon, Weight = 20 },
			{ Id = Rarities.Rare, Weight = 10 }
		}
	},
	[DirtDef.Ids.Uncommon] = {
		Name = "Uncommon Dirt",
		Rarity = Rarities.Uncommon,
		TotalHealth = 150,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Uncommon, Weight = 70 },
			{ Id = Rarities.Rare, Weight = 20 },
			{ Id = Rarities.Epic, Weight = 10 }
		}
	},
	[DirtDef.Ids.Rare] = {
		Name = "Rare Dirt",
		Rarity = Rarities.Rare,
		TotalHealth = 250,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Rare, Weight = 70 },
			{ Id = Rarities.Epic, Weight = 20 },
			{ Id = Rarities.Legendary, Weight = 10 }
		}
	},
	[DirtDef.Ids.Epic] = {
		Name = "Epic Dirt",
		Rarity = Rarities.Epic,
		TotalHealth = 400,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Epic, Weight = 70 },
			{ Id = Rarities.Legendary, Weight = 20 },
			{ Id = Rarities.Mythical, Weight = 10 }
		}
	},
	[DirtDef.Ids.Legendary] = {
		Name = "Legendary Dirt",
		Rarity = Rarities.Legendary,
		TotalHealth = 600,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Legendary, Weight = 70 },
			{ Id = Rarities.Mythical, Weight = 20 },
			{ Id = Rarities.Secret, Weight = 10 }
		}
	},
	[DirtDef.Ids.Mythical] = {
		Name = "Mythical Dirt",
		Rarity = Rarities.Mythical,
		TotalHealth = 1000,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Mythical, Weight = 80 },
			{ Id = Rarities.Secret, Weight = 20 }
		}
	},
	[DirtDef.Ids.SecretDirt] = {
		Name = "Secret Dirt",
		Rarity = Rarities.Secret,
		TotalHealth = 2000,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Secret, Weight = 100 }
		}
	}
}

function DirtDef.GetDirtInfo(dirtId)
	return DirtDef.Table[dirtId]
end

return DirtDef
