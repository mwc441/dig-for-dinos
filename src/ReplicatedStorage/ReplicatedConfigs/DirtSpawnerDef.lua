local DirtDef = require(script.Parent:WaitForChild("DirtDef"))

local DirtSpawnerDef = {}

-- Name each BasePart tagged "DirtSpawner" with one of these IDs.
DirtSpawnerDef.Table = {
	["Default"] = {
		InitialDirt = 5,
		MaxDirt = 10,
		SpawnCooldown = 15,
		DirtLootTable = {
			{ Id = DirtDef.Ids.Common, Weight = 60 },
			{ Id = DirtDef.Ids.Uncommon, Weight = 25 },
			{ Id = DirtDef.Ids.Rare, Weight = 10 },
			{ Id = DirtDef.Ids.Epic, Weight = 4 },
			{ Id = DirtDef.Ids.Legendary, Weight = 1 }
		},
		ScaleLootTable = {
			{ MinScale = 1, MaxScale = 1, Weight = 90 },
			{ MinScale = 1.3, MaxScale = 1.6, Weight = 5 },
			{ MinScale = 1.6, MaxScale = 1.9, Weight = 3 },
			{ MinScale = 1.9, MaxScale = 2.2, Weight = 2 }
		}
	}
}

function DirtSpawnerDef.GetSpawnerInfo(id)
	return DirtSpawnerDef.Table[id]
end

return DirtSpawnerDef
