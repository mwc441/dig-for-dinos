local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local BoostsDef = require(ReplicatedConfigs:WaitForChild("BoostsDef"))
local BoostsEnum = require(Enums:WaitForChild("Boosts"))

local RebirthDef = {}

RebirthDef.Table = {
	[1] = {
		Cost = 500
	}
}

RebirthDef.Boosts = {
	BoostsEnum.RebirthCashBoost
}

function RebirthDef.GetRebirthInfo(id)
	return RebirthDef.Table[id]
end

function RebirthDef.GetMaxRebirth()
	return #RebirthDef.Table
end

function RebirthDef.GetAmountForRebirth(rebirth)
	local boostId = RebirthDef.Boosts[1]
	if not boostId then return 0 end

	local amount = BoostsDef.GetTotalAmountForBoostForLevel(boostId, rebirth)
	return amount
end

return RebirthDef