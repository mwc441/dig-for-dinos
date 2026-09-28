--[[
	WARNING!!!!!:::::!::!!::!
	Boost percentages have to be in DECIMAL FORM, so a 50% boost would be 0.5

	Also level amounts are additive, meaning if level 1 is 0.05 and level 2 is 0.06,
	the total amount will be 0.11 for level 2
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local TableUtils = require(External:WaitForChild("TableUtils"))
local BoostTypesEnum = require(Enums:WaitForChild("BoostTypes"))
local NumberTypesEnum = require(Enums:WaitForChild("NumberTypes"))
local BoostsEnum = require(Enums:WaitForChild("Boosts"))

local BoostsDef = {}

BoostsDef.Table = {
	[BoostsEnum.FriendBoost] = {
		Type = BoostTypesEnum.BricksEarnedBoost,
		NumberType = NumberTypesEnum.Multiplying,
		Name = "Friends Boost",
		Icon = "rbxassetid://117403910373763",
		Description = "Invite friends for +5%% bricks each!<br/>(Click to invite)<br/>x%0.2f",
		AmountFunction = function(level: number)
			if level <= 0 then return 1 end

			return 1 + (level * Constants.FriendBricksBonus)
		end,
		MaxLevel = Constants.MaxFriends
	},

	[BoostsEnum.RobloxPlusBoost] = {
		Type = BoostTypesEnum.BricksEarnedBoost,
		NumberType = NumberTypesEnum.Multiplying,
		Name = "Roblox Plus",
		Icon = "rbxassetid://75220652271430",
		Description = "Roblox Plus users get more bricks!<br/><br/>x%0.2f",
		AmountFunction = function(level: number)
			if level <= 0 then return 1 end

			return 1.20 + ((level - 1) * 0.20)
		end,
		MaxLevel = 4
	},

	-- GAMEPASSES
}

function BoostsDef.GetMaxLevelForBoost(boostId)
	local info = BoostsDef.GetBoostInfo(boostId)
	if not info then
		return
	end

	if info.Levels then
		return #info.Levels
	elseif info.MaxLevel then
		return info.MaxLevel
	else
		return math.huge
	end
end

function BoostsDef.GetBoostAtLevel(boostId, level)
	local boost = BoostsDef.Table[boostId]
	if not boost then
		return
	end

	if not boost.Levels then
		return
	end

	return boost.Levels[level] or {}
end

function BoostsDef.GetDescriptionOfBoostAtLevel(boostId, level)
	local boostInfo = BoostsDef.Table[boostId]
	if not boostInfo then
		return
	end

	local amount = BoostsDef.GetTotalAmountForBoostForLevel(boostId, level)

	if boostInfo.NumberType == NumberTypesEnum.Adding then
		local filledInDescription = string.format(boostInfo.Description, amount * 100)
		return filledInDescription
	else
		local filledInDescription = string.format(boostInfo.Description, amount)
		return filledInDescription
	end
end

function BoostsDef.GetAmountForBoostAtLevel(boostId, level)
	return BoostsDef.GetBoostAtLevel(boostId, level).Amount
end

function BoostsDef.GetTotalAmountForBoostForLevel(boostId, level) : number
	local boostInfo = BoostsDef.GetBoostInfo(boostId)
	if not boostInfo then
		return 0
	end

	local max = BoostsDef.GetMaxLevelForBoost(boostId)

	level = math.min(level, max)

	local total = 0

	if boostInfo.AmountPerLevel then
		total = boostInfo.AmountPerLevel * level
	elseif boostInfo.Levels then
		for i = 1, level do
			total += (BoostsDef.GetAmountForBoostAtLevel(boostId, i) or 0)
		end
	elseif boostInfo.AmountFunction then
		total = boostInfo.AmountFunction(level)
	end

	return total
end

function BoostsDef.GetBoostsOfCategory(category)
	local boosts = {}
	for boostId, boost in pairs(BoostsDef.Table) do
		if boost.Category == category then
			local boostCopy = TableUtils.Copy(boost)
			boostCopy.Id = boostId

			table.insert(boosts, boostCopy)
		end
	end

	return boosts
end

function BoostsDef.GetBoostInfo(boostId)
	return BoostsDef.Table[boostId]
end

return BoostsDef
