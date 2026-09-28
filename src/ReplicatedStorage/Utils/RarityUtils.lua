local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local TableUtils = require(External:WaitForChild("TableUtils"))

local RarityUtils = {}

local SMALL_ROLL_THRESHOLD = 500

function RarityUtils.GetTotalWeightOfLootTable(lootTable)
	local weight = 0
	for _, loot in pairs(lootTable) do
		weight += loot.Weight
	end

	return weight
end

function RarityUtils.AdjustLootTableWithLuckBoost(lootTable, luckBoost)
	table.sort(lootTable, function(a, b)
		return a.Weight > b.Weight
	end)

	local rollCount = 1 + (luckBoost or 0)
	local totalWeight = RarityUtils.GetTotalWeightOfLootTable(lootTable)
	local cumulativeFromBottom = {}
	local adjustedProbabilities = {}
	local cumulative = 0
	local newLootTable = {}

	for i = #lootTable, 1, -1 do
		local entry = lootTable[i]

		cumulative = cumulative + (entry.Weight / totalWeight)
		cumulativeFromBottom[i] = cumulative
	end

	local nextBetterProbability = 0
	for i = #lootTable, 1, -1 do
		local atLeastThis = cumulativeFromBottom[i]

		local boostedAtLeastThis = 1 - (1 - atLeastThis) ^ rollCount

		adjustedProbabilities[i] = boostedAtLeastThis - nextBetterProbability

		nextBetterProbability = boostedAtLeastThis
	end

	for i, entry in pairs(lootTable) do
		local newEntry = TableUtils.Copy(entry)
		newEntry.Weight = adjustedProbabilities[i] * totalWeight
		table.insert(newLootTable, newEntry)
	end

	return newLootTable
end

function RarityUtils.RollHighestNumber(lowNumber, highNumber, rolls)
	rolls = rolls or 1

	local rng = Random.new()
	local u = 1 - rng:NextNumber() -- (0,1]
	local t = u ^ (1 / rolls)

	return lowNumber + (highNumber - lowNumber) * t
end

function RarityUtils.GetLootTableResults(lootTable, luckBoost)
	table.sort(lootTable, function(a, b)
		return a.Weight > b.Weight
	end)

	-- Boost has to be a percentage in decimal form, so 50% is 0.5
	local totalWeight = RarityUtils.GetTotalWeightOfLootTable(lootTable)

	local randomNumber = RarityUtils.RollHighestNumber(0, totalWeight, 1 + (luckBoost or 0))

	local latestEntry
	for _, entry in pairs(lootTable) do
		latestEntry = entry

		if randomNumber <= entry.Weight then
			return entry
		else -- no item, subtracts the weight from randomNumber
			randomNumber = randomNumber - entry.Weight
		end
	end

	-- A fallback just in case
	return latestEntry
end

-- Each loot entry needs a Weight AND a Id
function RarityUtils.GetBulkLootTableResults(lootTable, quantity, luckBoost) : { [string] : number }
	table.sort(lootTable, function(a, b)
		return a.Weight > b.Weight
	end)

	luckBoost = luckBoost or 0

	local random = Random.new(os.clock())
	local results = {}

	-- SMALL: real RNG
	if quantity <= SMALL_ROLL_THRESHOLD then
		for _ = 1, quantity do
			local id = RarityUtils.GetLootTableResults(lootTable, luckBoost).Id
			results[id] = (results[id] or 0) + 1
		end

		return results
	end

	-- LARGE: bulk math
	local totalGiven = 0
	local adjustedLootTable = RarityUtils.AdjustLootTableWithLuckBoost(lootTable, luckBoost)
	local totalWeight = RarityUtils.GetTotalWeightOfLootTable(adjustedLootTable)

	for _, entry in ipairs(adjustedLootTable) do
		local probability = entry.Weight / totalWeight

		local expected = quantity * probability

		local amount = 0

		if expected < 1 then
			if random:NextNumber() < expected then
				amount = 1
			end
		else
			local variance = math.sqrt(expected)
			local randomOffset = (random:NextNumber() - 0.5) * 2 * variance

			amount = math.max(0, math.floor(expected + randomOffset))
		end

		if amount > 0 then
			results[entry.Id] = amount
			totalGiven += amount
		end
	end

	local missing = quantity - totalGiven

	while missing > 0 do
		local id = RarityUtils.GetLootTableResults(lootTable, luckBoost).Id
		results[id] = (results[id] or 0) + 1
		missing -= 1
	end

	return results
end

return RarityUtils