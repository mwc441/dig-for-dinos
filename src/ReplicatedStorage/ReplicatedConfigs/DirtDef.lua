local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage:WaitForChild("Enums"):WaitForChild("Rarities"))

local DirtDef = {}

-- bigger piles have more health than just their size. 1.5 means a 2x pile has ~2.8x health, a 2.2x pile ~3.3x
-- set to 1 for health = size, 0 to turn it off
DirtDef.SizeHealthExponent = 1.5

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
-- every pile rolls its own rarity or higher. each step up is way rarer (common pile: 77 / 19 / 3.4 / 0.5 / 0.1 / 0.025 / 0.001). gambling baby
-- top piles are capped so secrets dont get fuckin handed out: legendary piles 1.5% secret, mythical piles 6% secret
-- every pile can drop a secret but common piles are like 1 in 100K, its a lottery ticket. zone 3 and 6 are the real secret farming spots
-- mythicals were spawning way too much so everything above rare got nerfed hard, good shit should feel rare
-- this health gets multiplied by the zone's HealthMultiplier in DirtSpawnerDef, so dont freak out at the small numbers
DirtDef.Table = {
	[DirtDef.Ids.Common] = {
		Name = "Common Dirt",
		Rarity = Rarities.Common,
		TotalHealth = 100,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Common, Weight = 77 },
			{ Id = Rarities.Uncommon, Weight = 19 },
			{ Id = Rarities.Rare, Weight = 3.4 },
			{ Id = Rarities.Epic, Weight = 0.5 },
			{ Id = Rarities.Legendary, Weight = 0.1 },
			{ Id = Rarities.Mythical, Weight = 0.025 },
			{ Id = Rarities.Secret, Weight = 0.001 },
		},
	},
	[DirtDef.Ids.Uncommon] = {
		Name = "Uncommon Dirt",
		Rarity = Rarities.Uncommon,
		TotalHealth = 150,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Uncommon, Weight = 77 },
			{ Id = Rarities.Rare, Weight = 19 },
			{ Id = Rarities.Epic, Weight = 3.4 },
			{ Id = Rarities.Legendary, Weight = 0.5 },
			{ Id = Rarities.Mythical, Weight = 0.1 },
			{ Id = Rarities.Secret, Weight = 0.005 },
		},
	},
	[DirtDef.Ids.Rare] = {
		Name = "Rare Dirt",
		Rarity = Rarities.Rare,
		TotalHealth = 250,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Rare, Weight = 78 },
			{ Id = Rarities.Epic, Weight = 18 },
			{ Id = Rarities.Legendary, Weight = 3.2 },
			{ Id = Rarities.Mythical, Weight = 0.6 },
			{ Id = Rarities.Secret, Weight = 0.06 },
		},
	},
	[DirtDef.Ids.Epic] = {
		Name = "Epic Dirt",
		Rarity = Rarities.Epic,
		TotalHealth = 400,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Epic, Weight = 80 },
			{ Id = Rarities.Legendary, Weight = 16.5 },
			{ Id = Rarities.Mythical, Weight = 2.8 },
			{ Id = Rarities.Secret, Weight = 0.45 },
		},
	},
	[DirtDef.Ids.Legendary] = {
		Name = "Legendary Dirt",
		Rarity = Rarities.Legendary,
		TotalHealth = 650,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Legendary, Weight = 86.5 },
			{ Id = Rarities.Mythical, Weight = 11.5 },
			{ Id = Rarities.Secret, Weight = 1.5 },
		},
	},
	[DirtDef.Ids.Mythical] = {
		Name = "Mythical Dirt",
		Rarity = Rarities.Mythical,
		TotalHealth = 1_100,
		DinosaurRarityLootTable = {
			{ Id = Rarities.Mythical, Weight = 94 },
			{ Id = Rarities.Secret, Weight = 6 },
		},
	},
	[DirtDef.Ids.SecretDirt] = {
		Name = "Secret Dirt",
		Rarity = Rarities.Secret,
		TotalHealth = 3_000, -- was 8000, ppl have way less dig power now that rebirths dont snowball
		DinosaurRarityLootTable = {
			{ Id = Rarities.Secret, Weight = 100 },
		},
	},
}

function DirtDef.GetDirtInfo(dirtId)
	return DirtDef.Table[dirtId]
end

return DirtDef
