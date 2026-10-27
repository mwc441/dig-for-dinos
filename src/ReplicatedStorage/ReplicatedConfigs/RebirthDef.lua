local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local BoostsDef = require(ReplicatedConfigs:WaitForChild("BoostsDef"))
local BoostsEnum = require(Enums:WaitForChild("Boosts"))

local RebirthDef = {}

-- 30 rebirths now cuz ppl need that rebirth dopamine. first one is like 10 min in, then every 10-15 min early, slowing down to every few hours late
-- each one gives +0.25x cash (RebirthCashBoost) and 1.12x dig power training (RebirthDigPowerBoost, like x30 by rebirth 30). smaller boosts but twice as many so the endgame is the same
RebirthDef.Table = {
	[1] = { Cost = 50_000 },
	[2] = { Cost = 600_000 },
	[3] = { Cost = 1_800_000 },
	[4] = { Cost = 4_000_000 },
	[5] = { Cost = 8_000_000 },
	[6] = { Cost = 25_000_000 },
	[7] = { Cost = 50_000_000 },
	[8] = { Cost = 100_000_000 },
	[9] = { Cost = 175_000_000 },
	[10] = { Cost = 400_000_000 },
	[11] = { Cost = 650_000_000 },
	[12] = { Cost = 1_000_000_000 },
	[13] = { Cost = 1_500_000_000 },
	[14] = { Cost = 2_200_000_000 },
	[15] = { Cost = 3_000_000_000 },
	[16] = { Cost = 4_500_000_000 },
	[17] = { Cost = 7_000_000_000 },
	[18] = { Cost = 9_500_000_000 },
	[19] = { Cost = 12_500_000_000 },
	[20] = { Cost = 16_000_000_000 },
	[21] = { Cost = 20_000_000_000 },
	[22] = { Cost = 26_000_000_000 },
	[23] = { Cost = 40_000_000_000 },
	[24] = { Cost = 55_000_000_000 },
	[25] = { Cost = 75_000_000_000 },
	[26] = { Cost = 120_000_000_000 },
	[27] = { Cost = 250_000_000_000 },
	[28] = { Cost = 450_000_000_000 },
	[29] = { Cost = 650_000_000_000 },
	[30] = { Cost = 800_000_000_000 },
}

RebirthDef.Boosts = {
	Cash = BoostsEnum.RebirthCashBoost,
	DigPower = BoostsEnum.RebirthDigPowerBoost,
}

function RebirthDef.GetRebirthInfo(id)
	return RebirthDef.Table[id]
end

function RebirthDef.GetMaxRebirth()
	return #RebirthDef.Table
end

function RebirthDef.GetAmountForRebirth(rebirth, boostType)
	local boostId = RebirthDef.Boosts[boostType or "Cash"]
	if not boostId then
		return 0
	end

	local amount = BoostsDef.GetTotalAmountForBoostForLevel(boostId, rebirth)
	return amount
end

return RebirthDef
