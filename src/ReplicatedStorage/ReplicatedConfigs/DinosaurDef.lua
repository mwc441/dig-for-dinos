local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage:WaitForChild("Enums"):WaitForChild("Rarities"))

local DinosaurDef = {}

DinosaurDef.Ids = {
	Trex = "Trex"
}

DinosaurDef.Table = {
	[DinosaurDef.Ids.Trex] = {
		Name = "Trex",
		Rarity = Rarities.Common,
		Income = 50,
		Weight = 100
	}
}

function DinosaurDef.GetDinosaurInfo(id)
	return DinosaurDef.Table[id]
end

function DinosaurDef.GetLootTableForRarity(rarity)
	local lootTable = {}
	for id, info in pairs(DinosaurDef.Table) do
		if info.Rarity == rarity then
			table.insert(lootTable, { Id = id, Weight = info.Weight })
		end
	end

	return lootTable
end

return DinosaurDef
