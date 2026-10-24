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
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))

local BoostsDef = {}

BoostsDef.Table = {
	[BoostsEnum.FriendBoost] = {
		Type = BoostTypesEnum.CashBoost,
		NumberType = NumberTypesEnum.Multiplying,
		Name = "Friends Boost",
		Icon = "rbxassetid://117403910373763",
		Description = "Invite friends for <font color=\"#55ff00\">+10%% cash</font> each!<br/><font color=\"#55ff00\">(Click to invite)</font><br/>x%0.2f",
		AmountFunction = function(level: number)
			if level <= 0 then return 1 end

			return 1 + (level * Constants.CashPerFriend)
		end,
		MaxLevel = Constants.MaxFriends
	},

	[BoostsEnum.RobloxPlusBoost] = {
		Type = BoostTypesEnum.CashBoost,
		NumberType = NumberTypesEnum.Multiplying,
		Name = "Roblox Plus",
		Icon = "rbxassetid://75220652271430",
		Description = "Roblox Plus users get more cash!<br/><br/>x%0.2f",
		AmountFunction = function(level: number)
			if level <= 0 then return 1 end

			return 1.20 + ((level - 1) * 0.20)
		end,
		MaxLevel = 4
	},

	[BoostsEnum.RebirthCashBoost] = {
		Type = BoostTypesEnum.CashBoost,
		NumberType = NumberTypesEnum.Multiplying,
		Name = "Rebirth Cash",
		AmountFunction = function(level: number)
			return 1 + (level * 0.5)
		end
	},

	[BoostsEnum.NormalIndexCashBoost] = {
		Type = BoostTypesEnum.CashBoost,
		NumberType = NumberTypesEnum.Adding,
		Icon = Constants.Icons[PlayerStatsEnum.Cash],
		AmountFunction = function(level: number)
			return level * 0.05
		end
	},

	[BoostsEnum.GoldIndexCashBoost] = {
		Type = BoostTypesEnum.CashBoost,
		NumberType = NumberTypesEnum.Adding,
		Icon = Constants.Icons[PlayerStatsEnum.Cash],
		AmountFunction = function(level: number)
			return level * 0.05
		end
	},

	[BoostsEnum.VoidIndexCashBoost] = {
		Type = BoostTypesEnum.CashBoost,
		NumberType = NumberTypesEnum.Adding,
		Icon = Constants.Icons[PlayerStatsEnum.Cash],
		AmountFunction = function(level: number)
			return level * 0.05
		end
	},

	[BoostsEnum.FlameIndexCashBoost] = {
		Type = BoostTypesEnum.CashBoost,
		NumberType = NumberTypesEnum.Adding,
		Icon = Constants.Icons[PlayerStatsEnum.Cash],
		AmountFunction = function(level: number)
			return level * 0.05
		end
	},

	[BoostsEnum.GoldWeatherBoost] = {
		Type = BoostTypesEnum.GoldMutationChanceBoost,
		NumberType = NumberTypesEnum.Multiplying,
		Name = "Gold Weather",
		Icon = "rbxassetid://84279161348248",
		Description = "Gold Dinosaur Luck<br/><br/>x%d",
		AmountFunction = function(level: number)
			return 1 + level
		end
	},

	[BoostsEnum.VoidWeatherBoost] = {
		Type = BoostTypesEnum.VoidMutationChanceBoost,
		NumberType = NumberTypesEnum.Multiplying,
		Name = "Void Weather",
		Icon = "rbxassetid://104998627371322",
		Description = "Void Dinosaur Luck<br/><br/>x%d",
		AmountFunction = function(level: number)
			return 1 + level
		end
	},

	[BoostsEnum.FlameWeatherBoost] = {
		Type = BoostTypesEnum.FlameMutationChanceBoost,
		NumberType = NumberTypesEnum.Multiplying,
		Name = "Flame Weather",
		Icon = "rbxassetid://103784198225882",
		Description = "Flame Dinosaur Luck<br/><br/>x%d",
		AmountFunction = function(level: number)
			return 1 + level
		end
	},

	[BoostsEnum.CashWeatherBoost] = {
		Type = BoostTypesEnum.CashBoost,
		NumberType = NumberTypesEnum.Multiplying,
		Name = "Cash Weather",
		Icon = Constants.Icons[PlayerStatsEnum.Cash],
		Description = "Cash x%d",
		AmountFunction = function(level: number)
			return 1 + level
		end
	},

	[BoostsEnum.RadioactiveWeatherBoost] = {
		Type = BoostTypesEnum.DigPowerTrainingBoost,
		NumberType = NumberTypesEnum.Multiplying,
		Name = "Radioactive Weather",
		Icon = "rbxassetid://73000488313692",
		Description = "Dig Power Training<br/><br/>x%d",
		AmountFunction = function(level: number)
			return 1 + level
		end
	},

	-- GAMEPASSES
	[BoostsEnum.VIPCashBoost] = {
		Type = BoostTypesEnum.CashBoost,
		NumberType = NumberTypesEnum.Multiplying,
		Name = "VIP",
		Icon = "rbxassetid://86493387113836",
		Description = "2x Cash<br/><br/>2x Dig Power Training",
		AmountFunction = function()
			return 2
		end
	},

	[BoostsEnum.VIPDigPowerBoost] = {
		Type = BoostTypesEnum.DigPowerTrainingBoost,
		NumberType = NumberTypesEnum.Multiplying,
		Name = "VIP",
		AmountFunction = function()
			return 2
		end
	},

	[BoostsEnum.Cash2xBoost] = {
		Type = BoostTypesEnum.CashBoost,
		NumberType = NumberTypesEnum.Multiplying,
		Name = "Gamepass",
		Description = "%dx Cash",
		Icon = "rbxassetid://107540056404677",
		AmountFunction = function(level: number)
			return 2 ^ level
		end
	},

	[BoostsEnum.DigPower2xBoost] = {
		Type = BoostTypesEnum.DigPowerTrainingBoost,
		NumberType = NumberTypesEnum.Multiplying,
		Name = "Gamepass",
		Description = "2x Dig Power Training",
		Icon = "rbxassetid://87407472042343",
		AmountFunction = function()
			return 2
		end
	},

	-- UGPRADES
	[BoostsEnum.SpeedUpgradeBoost] = {
		Type = BoostTypesEnum.WalkSpeedBoost,
		NumberType = NumberTypesEnum.Adding,
		Name = "Speed",
		AmountFunction = function(level: number)
			return level
		end
	}
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
