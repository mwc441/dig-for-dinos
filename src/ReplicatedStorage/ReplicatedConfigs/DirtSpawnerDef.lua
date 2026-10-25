local DirtDef = require(script.Parent:WaitForChild("DirtDef"))
local DinosaurDef = require(script.Parent:WaitForChild("DinosaurDef"))
local Rarities = require(script.Parent.Parent:WaitForChild("Enums"):WaitForChild("Rarities"))

local DirtSpawnerDef = {}

DirtSpawnerDef.DinosaurPools = {
	Zones1To3 = {
		DinosaurDef.Ids.Triceratops,
		DinosaurDef.Ids.Ableisaurus,
		DinosaurDef.Ids.Microraptor,
		DinosaurDef.Ids.Brachiosaurus,
		DinosaurDef.Ids.Utahraptor,
		DinosaurDef.Ids.Troodon,
		DinosaurDef.Ids.Tung,
		DinosaurDef.Ids.Majungasaurus,
		DinosaurDef.Ids.Gallimimus,
		DinosaurDef.Ids.Velociraptor,
		DinosaurDef.Ids.Dilophosaurus,
		DinosaurDef.Ids.Pterodactyl,
		DinosaurDef.Ids.Trex,
	},
	Zones4To6 = {
		DinosaurDef.Ids.Carnotaurus,
		DinosaurDef.Ids.Carcharodontosaurus,
		DinosaurDef.Ids.Giganotosaurus,
		DinosaurDef.Ids.Allosaurus,
		DinosaurDef.Ids.Cryolophosaurus,
		DinosaurDef.Ids.Monolophosaurus,
		DinosaurDef.Ids.BallerinaSkeletina,
		DinosaurDef.Ids.Quetzalcoatlus,
		DinosaurDef.Ids.HornedGallimimus,
		DinosaurDef.Ids.Deinonychus,
		DinosaurDef.Ids.Pachycephalosaurus,
		DinosaurDef.Ids.Plesiosaurus,
		DinosaurDef.Ids.Hydra,
	},
	Zone7 = {
		DinosaurDef.Ids.Camarasaurus,
		DinosaurDef.Ids.Ceratosaurus,
		DinosaurDef.Ids.Protoceratops,
		DinosaurDef.Ids.Pachyrhinosaurus,
		DinosaurDef.Ids.Styracosaurus,
		DinosaurDef.Ids.Therizinosaurus,
		DinosaurDef.Ids.Dragon,
	},
}

DirtSpawnerDef.GuaranteedSpawns = {
	{ Rarity = Rarities.Legendary, DirtId = DirtDef.Ids.Legendary, IntervalSeconds = 20 * 60 },
	{ Rarity = Rarities.Mythical, DirtId = DirtDef.Ids.Mythical, IntervalSeconds = 45 * 60 },
	{ Rarity = Rarities.Secret, DirtId = DirtDef.Ids.SecretDirt, IntervalSeconds = 60 * 60 },
}

local DirtIdsByRarity = {
	DirtDef.Ids.Common,
	DirtDef.Ids.Uncommon,
	DirtDef.Ids.Rare,
	DirtDef.Ids.Epic,
	DirtDef.Ids.Legendary,
	DirtDef.Ids.Mythical,
	DirtDef.Ids.SecretDirt,
}

local ScaleLootTable = {
	{ MinScale = 1, MaxScale = 1, Weight = 90 },
	{ MinScale = 1.3, MaxScale = 1.6, Weight = 5 },
	{ MinScale = 1.6, MaxScale = 1.9, Weight = 3 },
	{ MinScale = 1.9, MaxScale = 2.2, Weight = 2 },
}

local function makeSpawner(zoneId, healthMultiplier, dinosaurIds, rarityWeights)
	local dirtLootTable = {}
	for index, dirtId in ipairs(DirtIdsByRarity) do
		table.insert(dirtLootTable, { Id = dirtId, Weight = rarityWeights[index] })
	end

	return {
		Zone = zoneId,
		DinosaurIds = dinosaurIds,
		HealthMultiplier = healthMultiplier,
		InitialDirt = 5,
		MaxDirt = 10,
		SpawnCooldown = 15,
		DirtLootTable = dirtLootTable,
		ScaleLootTable = ScaleLootTable,
	}
end

-- Rarity weights: Common, Uncommon, Rare, Epic, Legendary, Mythical, Secret.
-- Name each BasePart tagged "DirtSpawner" with one of these zone IDs.
DirtSpawnerDef.Table = {
	-- set 1 (zones 1-3): 5x health each step. deeper zones = better piles, go deeper u bum
	["Zone1"] = makeSpawner("Zone1", 1, DirtSpawnerDef.DinosaurPools.Zones1To3, { 74, 20.5, 4.4, 0.8, 0.15, 0.025, 0.008 }),
	["Zone2"] = makeSpawner("Zone2", 5, DirtSpawnerDef.DinosaurPools.Zones1To3, { 60, 27, 9.5, 2.6, 0.6, 0.1, 0.016 }),
	["Zone3"] = makeSpawner("Zone3", 25, DirtSpawnerDef.DinosaurPools.Zones1To3, { 48, 31, 15, 4.8, 1.2, 0.25, 0.03 }),
	-- set 2 (zones 4-6): fat 40x wall into zone 4 then 4x steps. odds reset then get good again
	["Zone4"] = makeSpawner(
		"Zone4",
		1_000,
		DirtSpawnerDef.DinosaurPools.Zones4To6,
		{ 74, 20.5, 4.4, 0.8, 0.15, 0.025, 0.008 }
	),
	["Zone5"] = makeSpawner("Zone5", 4_000, DirtSpawnerDef.DinosaurPools.Zones4To6, { 60, 27, 9.5, 2.6, 0.6, 0.1, 0.016 }),
	["Zone6"] = makeSpawner("Zone6", 16_000, DirtSpawnerDef.DinosaurPools.Zones4To6, { 48, 31, 15, 4.8, 1.2, 0.25, 0.03 }),
	-- zone 7 (first solo zone): another 40x wall. secret odds kept low on purpose so the dragon stays rare as shit
	["Zone7"] = makeSpawner("Zone7", 650_000, DirtSpawnerDef.DinosaurPools.Zone7, { 54, 28, 12.5, 4, 1, 0.18, 0.02 }),
}

function DirtSpawnerDef.GetSpawnerInfo(id)
	return DirtSpawnerDef.Table[id]
end

return DirtSpawnerDef
