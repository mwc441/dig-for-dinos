local DirtDef = require(script.Parent:WaitForChild("DirtDef"))
local DinosaurDef = require(script.Parent:WaitForChild("DinosaurDef"))
local Rarities = require(script.Parent.Parent:WaitForChild("Enums"):WaitForChild("Rarities"))

local DirtSpawnerDef = {}

DirtSpawnerDef.DinosaurPools = {
	Zones1To3 = {
		DinosaurDef.Ids.Triceratops,
		DinosaurDef.Ids.Brachiosaurus,
		DinosaurDef.Ids.Tung,
		DinosaurDef.Ids.Velociraptor,
		DinosaurDef.Ids.Dilophosaurus,
		DinosaurDef.Ids.Pterodactyl,
		DinosaurDef.Ids.Trex
	},
	Zones4To6 = {
		DinosaurDef.Ids.Carnotaurus,
		DinosaurDef.Ids.Allosaurus,
		DinosaurDef.Ids.BallerinaSkeletina,
		DinosaurDef.Ids.Deinonychus,
		DinosaurDef.Ids.Pachycephalosaurus,
		DinosaurDef.Ids.Plesiosaurus,
		DinosaurDef.Ids.Hydra
	},
	Zone7 = {
		DinosaurDef.Ids.Camarasaurus,
		DinosaurDef.Ids.Ceratosaurus,
		DinosaurDef.Ids.Protoceratops,
		DinosaurDef.Ids.Pachyrhinosaurus,
		DinosaurDef.Ids.Styracosaurus,
		DinosaurDef.Ids.Therizinosaurus,
		DinosaurDef.Ids.Dragon
	}
}

DirtSpawnerDef.GuaranteedSpawns = {
	{ Rarity = Rarities.Legendary, DirtId = DirtDef.Ids.Legendary, IntervalSeconds = 10 * 60 },
	{ Rarity = Rarities.Mythical, DirtId = DirtDef.Ids.Mythical, IntervalSeconds = 30 * 60 },
	{ Rarity = Rarities.Secret, DirtId = DirtDef.Ids.SecretDirt, IntervalSeconds = 60 * 60 }
}

local DirtIdsByRarity = {
	DirtDef.Ids.Common,
	DirtDef.Ids.Uncommon,
	DirtDef.Ids.Rare,
	DirtDef.Ids.Epic,
	DirtDef.Ids.Legendary,
	DirtDef.Ids.Mythical,
	DirtDef.Ids.SecretDirt
}

local ScaleLootTable = {
	{ MinScale = 1, MaxScale = 1, Weight = 90 },
	{ MinScale = 1.3, MaxScale = 1.6, Weight = 5 },
	{ MinScale = 1.6, MaxScale = 1.9, Weight = 3 },
	{ MinScale = 1.9, MaxScale = 2.2, Weight = 2 }
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
		ScaleLootTable = ScaleLootTable
	}
end

-- Rarity weights: Common, Uncommon, Rare, Epic, Legendary, Mythical, Secret.
-- Name each BasePart tagged "DirtSpawner" with one of these zone IDs.
DirtSpawnerDef.Table = {
	["Zone1"] = makeSpawner("Zone1", 1, DirtSpawnerDef.DinosaurPools.Zones1To3, { 60, 25, 10, 4, 1, 1, 1 }),
	["Zone2"] = makeSpawner("Zone2", 1.5, DirtSpawnerDef.DinosaurPools.Zones1To3, { 52, 26, 13, 6, 2, 1, 1 }),
	["Zone3"] = makeSpawner("Zone3", 2, DirtSpawnerDef.DinosaurPools.Zones1To3, { 45, 27, 16, 8, 3, 1, 1 }),
	["Zone4"] = makeSpawner("Zone4", 3, DirtSpawnerDef.DinosaurPools.Zones4To6, { 38, 27, 19, 10, 4, 2, 1 }),
	["Zone5"] = makeSpawner("Zone5", 4, DirtSpawnerDef.DinosaurPools.Zones4To6, { 30, 26, 22, 13, 6, 3, 1 }),
	["Zone6"] = makeSpawner("Zone6", 5, DirtSpawnerDef.DinosaurPools.Zones4To6, { 24, 23, 24, 17, 8, 4, 2 }),
	["Zone7"] = makeSpawner("Zone7", 7, DirtSpawnerDef.DinosaurPools.Zone7, { 18, 20, 25, 20, 10, 5, 2 })
}

function DirtSpawnerDef.GetSpawnerInfo(id)
	return DirtSpawnerDef.Table[id]
end

return DirtSpawnerDef
