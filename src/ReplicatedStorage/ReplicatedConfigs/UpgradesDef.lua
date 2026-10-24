local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local BoostsDef = require(ReplicatedConfigs:WaitForChild("BoostsDef"))
local IapsEnum = require(Enums:WaitForChild("Iaps"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local BoostsEnum = require(Enums:WaitForChild("Boosts"))

local UpgradesDef = {}

UpgradesDef.Table = {
	["BearTrapUpgrade"] = {
		Name = "Bear Trap Place Limit",
		Icon = "rbxassetid://76727775766182",
		IapId = IapsEnum.BearTrapUpgrade,
		CostFunction = function(level: number)
			return 500 * level
		end,
		CostType = PlayerStatsEnum.Cash,
		MaxLevel = 4,
		AmountFunction = function(level: number)
			return 1 + level
		end
	},

	["DigTrainingSpeedUpgrade"] = {
		Name = "Dig Training Speed",
		Icon = "rbxassetid://139669454865825",
		IapId = IapsEnum.DigSpeedUpgrade,
		CostFunction = function(level: number)
			return 500 * level
		end,
		CostType = PlayerStatsEnum.Cash,
		MaxLevel = 10,
		AmountFunction = function(level: number)
			return 1 + level * 0.2
		end
	},

	["SpeedUpgrade"] = {
		Name = "Speed",
		Icon = "rbxassetid://136487360980411",
		IapId = IapsEnum.SpeedUpgrade,
		CostFunction = function(level: number)
			return 500 * level
		end,
		CostType = PlayerStatsEnum.Cash,
		MaxLevel = 10,
		Boost = BoostsEnum.SpeedUpgradeBoost
	}
}

function UpgradesDef.GetAllUpgrades()
	return UpgradesDef.Table
end

function UpgradesDef.GetUpgradeInfo(id)
	return UpgradesDef.Table[id]
end

function UpgradesDef.GetCostOfUpgrade(id, level)
	local info = UpgradesDef.GetUpgradeInfo(id)
	if not info then return end

	if info.CostFunction then
		return info.CostFunction(level)
	end
end

function UpgradesDef.GetMaxLevelForUpgrade(id)
	local info = UpgradesDef.GetUpgradeInfo(id)
	if not info then return 0 end

	return info.MaxLevel or math.huge
end

function UpgradesDef.GetAmountForUpgrade(id, level)
	local info = UpgradesDef.GetUpgradeInfo(id)
	if not info then return 0 end

	if info.AmountFunction then
		return info.AmountFunction(level)
	end

	local boostId = info.Boost
	if not boostId then return 0 end

	return BoostsDef.GetTotalAmountForBoostForLevel(boostId, level)
end

return UpgradesDef
