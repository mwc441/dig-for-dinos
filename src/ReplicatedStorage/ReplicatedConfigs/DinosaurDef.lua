local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage:WaitForChild("Enums"):WaitForChild("Rarities"))

local DinosaurDef = {}
local SELL_INCOME_SECONDS = 60

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

function DinosaurDef.GetAllDinosaurs()
	return DinosaurDef.Table
end

function DinosaurDef.GetDinosaurInfo(id)
	return DinosaurDef.Table[id]
end

function DinosaurDef.GetSellPrice(id, scale)
	local info = DinosaurDef.GetDinosaurInfo(id)
	if not info then return end

	return math.round((info.Income or 0) * scale) * SELL_INCOME_SECONDS
end

function DinosaurDef.GetIncome(id, scale)
	local info = DinosaurDef.GetDinosaurInfo(id)
	if not info then return end

	return (info.Income or 0) * scale
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
