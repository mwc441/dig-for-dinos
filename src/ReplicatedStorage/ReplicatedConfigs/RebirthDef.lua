local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local BoostsDef = require(ReplicatedConfigs:WaitForChild("BoostsDef"))
local BoostsEnum = require(Enums:WaitForChild("Boosts"))

local RebirthDef = {}

-- each rebirth gives +0.5x cash (RebirthCashBoost) and 1.25x dig power training (RebirthDigPowerBoost, like x28 by rebirth 15). worth it trust
RebirthDef.Table = {
	[1] = { Cost = 2_000_000 },
	[2] = { Cost = 15_000_000 },
	[3] = { Cost = 150_000_000 },
	[4] = { Cost = 750_000_000 },
	[5] = { Cost = 4_000_000_000 },
	[6] = { Cost = 10_000_000_000 },
	[7] = { Cost = 25_000_000_000 },
	[8] = { Cost = 40_000_000_000 },
	[9] = { Cost = 60_000_000_000 },
	[10] = { Cost = 150_000_000_000 },
	[11] = { Cost = 250_000_000_000 },
	[12] = { Cost = 400_000_000_000 },
	[13] = { Cost = 700_000_000_000 },
	[14] = { Cost = 1_300_000_000_000 },
	[15] = { Cost = 2_000_000_000_000 },
}

-- "RebirthDigPowerBoost" is just a string rn cuz its not in Enums/Boosts yet. lollypop fix ts, i think dig power would be a good help
RebirthDef.Boosts = {
	BoostsEnum.RebirthCashBoost,
	"RebirthDigPowerBoost",
}

function RebirthDef.GetRebirthInfo(id)
	return RebirthDef.Table[id]
end

function RebirthDef.GetMaxRebirth()
	return #RebirthDef.Table
end

function RebirthDef.GetAmountForRebirth(rebirth)
	local boostId = RebirthDef.Boosts[1]
	if not boostId then
		return 0
	end

	local amount = BoostsDef.GetTotalAmountForBoostForLevel(boostId, rebirth)
	return amount
end

return RebirthDef
