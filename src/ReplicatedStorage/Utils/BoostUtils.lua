local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local External = ReplicatedStorage:WaitForChild("External")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local NumberTypesEnum = require(Enums:WaitForChild("NumberTypes"))
local TableUtils = require(External:WaitForChild("TableUtils"))
local BoostsDef = require(ReplicatedConfigs:WaitForChild("BoostsDef"))

local BoostUtils = {}

export type Boost = {
	Id : string,
	Level : number,
	ExpiryTime : number?, -- UNIX TIME
	TimeLeft : number? -- In-game time left
}

export type Boosts = { Boost }

function BoostUtils.GetBoostInfo(boost: Boost)
	return BoostsDef.GetBoostInfo(boost.Id)
end

function BoostUtils.GetDescriptionOfBoost(boost: Boost)
	return BoostsDef.GetDescriptionOfBoostAtLevel(boost.Id, boost.Level)
end

function BoostUtils.GetBoostOfId(boosts: Boosts, id: string) : (Boost, number)
	for index, boost in pairs(boosts) do
		if boost.Id == id then
			return boost, index
		end
	end
end

function BoostUtils.GetBoostsOfType(boosts: Boosts, boostType: string) : Boosts
	local boostsOfType = {}
	for _, boost in pairs(boosts) do
		local boostInfo = BoostsDef.GetBoostInfo(boost.Id)
		if not boostInfo then
			continue
		end

		if boostInfo.Type == boostType then
			table.insert(boostsOfType, TableUtils.Copy(boost))
		end
	end

	return boostsOfType
end

function BoostUtils.GetOneTimeBoostsOfType(boosts: Boosts, boostType : string) : Boosts
	local oneTimeBoosts = {}
	for _, boost in pairs(boosts) do
		local boostInfo = BoostsDef.GetBoostInfo(boost.Id)
		if not boostInfo then
			continue
		end

		if (boostInfo.Type == boostType) and (boostInfo.OneTimeUse) then
			table.insert(oneTimeBoosts, TableUtils.Copy(boost))
		end
	end

	return oneTimeBoosts
end

function BoostUtils.GetAddingBoostAmountOfType(boosts: Boosts, boostType : string) : number
	local boostsOfType = BoostUtils.GetBoostsOfType(boosts, boostType)

	local totalBoostAmount = 0
	for _, boost in pairs(boostsOfType) do
		local boostInfo = BoostsDef.GetBoostInfo(boost.Id)
		if not boostInfo then
			continue
		end

		local numberType = boostInfo.NumberType or NumberTypesEnum.Adding
		if numberType ~= NumberTypesEnum.Adding then
			continue
		end

		if not boost.Level then
			continue
		end

		local amount = BoostsDef.GetTotalAmountForBoostForLevel(boost.Id, boost.Level)
		if not amount then
			continue
		end

		totalBoostAmount += amount
	end

	return totalBoostAmount
end

function BoostUtils.GetMultiplyingBoostAmountOfType(boosts: Boosts, boostType : string) : number
	local boostsOfType = BoostUtils.GetBoostsOfType(boosts, boostType)

	local totalBoostAmount = 1
	for _, boost in pairs(boostsOfType) do
		local boostInfo = BoostsDef.GetBoostInfo(boost.Id)
		if not boostInfo then
			continue
		end

		local numberType = boostInfo.NumberType or NumberTypesEnum.Adding
		if numberType ~= NumberTypesEnum.Multiplying then
			continue
		end

		if not boost.Level then
			continue
		end

		local amount = BoostsDef.GetTotalAmountForBoostForLevel(boost.Id, boost.Level)
		if not amount then
			continue
		end

		totalBoostAmount *= amount
	end

	return totalBoostAmount
end

function BoostUtils.AddBoost(boosts: Boosts, newBoost: Boost) : boolean
	if type(newBoost) ~= "table" then
		return false
	end

	if (not newBoost.Id) or (not newBoost.Level) then
		warn("The boost doesn't have the required info")
		return false
	end

	local info = BoostsDef.GetBoostInfo(newBoost.Id)
	if not info then
		warn("No info for boost")
		return false
	end

	local level = newBoost.Level
	local maxLevel = BoostsDef.GetMaxLevelForBoost(newBoost.Id)

	newBoost.Level = math.min(level, maxLevel)

	-- You can provide a certain time
	-- the boost will expire (unix time, so it will expire if offline)
	if newBoost.ExpiryTime then
		if os.time() >= newBoost.ExpiryTime then
			return false
		end
	end

	-- Or provide the amount of in-game time
	-- the boost will last for (will not count down offline)
	if newBoost.TimeLeft then
		if newBoost.TimeLeft <= 0 then
			return false
		end
	end

	if BoostUtils.GetBoostOfId(boosts, newBoost.Id) then
		warn("You cannot add another boost with the same Id")
		return false
	end

	table.insert(boosts, TableUtils.Copy(newBoost))

	return true
end

function BoostUtils.UpdateBoost(boosts: Boosts, boostId: string, newBoostData: Boost) : boolean
	local boost = BoostUtils.GetBoostOfId(boosts, boostId)
	if not boost then
		return
	end

	local changed = false
	for key, data in pairs(newBoostData) do
		if key == "Id" then
			warn("You cannot update a boosts Id")
			continue
		elseif key == "Level" then
			local maxLevel = BoostsDef.GetMaxLevelForBoost(boostId)

			data = math.min(data, maxLevel)
		end

		if boost[key] == data then
			continue
		end

		boost[key] = data
		changed = true
	end

	return changed
end

function BoostUtils.RemoveBoost(boosts: Boosts, boostId: string) : boolean
	for index, boost in pairs(boosts) do
		if boost.Id == boostId then
			table.remove(boosts, index)

			return true
		end
	end

	return false
end

return BoostUtils