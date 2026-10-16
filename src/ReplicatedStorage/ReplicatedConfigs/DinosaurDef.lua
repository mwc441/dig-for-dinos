local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local Constants = require(script.Parent:WaitForChild("Constants"))
local ZoneDef = require(script.Parent:WaitForChild("ZoneDef"))
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

function DinosaurDef.GetSellPrice(id, scale, mutation, zoneId)
	local info = DinosaurDef.GetDinosaurInfo(id)
	if not info then return end

	return DinosaurDef.GetIncome(id, scale, mutation, zoneId) * SELL_INCOME_SECONDS
end

function DinosaurDef.GetIncome(id, scale, mutation, zoneId)
	local info = DinosaurDef.GetDinosaurInfo(id)
	if not info then return end

	local mutationMultiplier = DinosaurDef.MutationIncomeMultipliers[mutation] or 1
	local zoneInfo = ZoneDef.GetZoneInfo(zoneId)
	local zoneMultiplier = zoneInfo and zoneInfo.IncomeMultiplier or 1

	return math.round((info.Income or 0) * scale * mutationMultiplier * zoneMultiplier)
end

function DinosaurDef.GetLootTableForRarity(rarity, allowedIds)
	if not allowedIds then return {} end

	local rarityRank = table.find(Constants.RarityOrder, rarity)
	if not rarityRank then return {} end

	local function getLootTableAtRank(rank)
		local lootTable = {}
		for _, id in ipairs(allowedIds) do
			local info = DinosaurDef.GetDinosaurInfo(id)
			if info and info.Rarity == Constants.RarityOrder[rank] then
				table.insert(lootTable, { Id = id, Weight = info.Weight })
			end
		end
		return lootTable
	end

	-- Prefer this rarity or a lower one; otherwise use the lowest eligible higher rarity.
	for rank = rarityRank, 1, -1 do
		local lootTable = getLootTableAtRank(rank)
		if #lootTable > 0 then return lootTable end
	end
	for rank = rarityRank + 1, #Constants.RarityOrder do
		local lootTable = getLootTableAtRank(rank)
		if #lootTable > 0 then return lootTable end
	end
	return {}
end

return DinosaurDef
