local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local RaritiesEnum = require(Enums:WaitForChild("Rarities"))
local MutationsEnum = require(Enums:WaitForChild("Mutations"))

local DinosaurDef = {}
local SELL_INCOME_SECONDS = 60

DinosaurDef.Ids = {
	Trex = "Trex"
}

DinosaurDef.Table = {
	[DinosaurDef.Ids.Trex] = {
		Name = "Trex",
		Rarity = RaritiesEnum.Common,
		Income = 50,
		Weight = 100
	}
}

DinosaurDef.MutationIncomeMultipliers = {
	[MutationsEnum.Normal] = 1,
	[MutationsEnum.Gold] = 2,
	[MutationsEnum.Void] = 5,
	[MutationsEnum.Flame] = 10
}

DinosaurDef.MutationLootTable = {
	{
		Id = MutationsEnum.Normal,
		Weight = 90
	},

	{
		Id = MutationsEnum.Gold,
		Weight = 5
	},

	{
		Id = MutationsEnum.Void,
		Weight = 4
	},

	{
		Id = MutationsEnum.Flame,
		Weight = 1
	}
}

function DinosaurDef.GetAllDinosaurs()
	return DinosaurDef.Table
end

function DinosaurDef.GetDinosaurInfo(id)
	return DinosaurDef.Table[id]
end

function DinosaurDef.GetSellPrice(id, scale, mutation)
	local info = DinosaurDef.GetDinosaurInfo(id)
	if not info then return end

	return DinosaurDef.GetIncome(id, scale, mutation) * SELL_INCOME_SECONDS
end

function DinosaurDef.GetIncome(id, scale, mutation)
	local info = DinosaurDef.GetDinosaurInfo(id)
	if not info then return end

	local mutationMultiplier = DinosaurDef.MutationIncomeMultipliers[mutation] or 1

	return math.round((info.Income or 0) * scale * mutationMultiplier)
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
