local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local BoostsDef = require(ReplicatedConfigs:WaitForChild("BoostsDef"))
local BoostsEnum = require(Enums:WaitForChild("Boosts"))

local RebirthDef = {}

-- 40 rebirths now. every 5th one is a WALL, big price jump (10x at first, grows to like 30x by the end). the 4 in between are cheap, 1.2x each
-- every rebirth gives +0.25x cash (RebirthCashBoost). ONLY walls give dig power, 1.2x each (RebirthDigPowerBoost). this kills the snowball
-- 31-40 are endgame goals for vets till the next update drops
RebirthDef.Table = {
	[1] = { Cost = 100_000 },
	[2] = { Cost = 120_000 },
	[3] = { Cost = 140_000 },
	[4] = { Cost = 170_000 },
	[5] = { Cost = 1_700_000 }, -- WALL
	[6] = { Cost = 2_100_000 },
	[7] = { Cost = 2_500_000 },
	[8] = { Cost = 3_000_000 },
	[9] = { Cost = 3_600_000 },
	[10] = { Cost = 41_000_000 }, -- WALL
	[11] = { Cost = 49_000_000 },
	[12] = { Cost = 59_000_000 },
	[13] = { Cost = 71_000_000 },
	[14] = { Cost = 85_000_000 },
	[15] = { Cost = 1_100_000_000 }, -- WALL
	[16] = { Cost = 1_400_000_000 },
	[17] = { Cost = 1_600_000_000 },
	[18] = { Cost = 2_000_000_000 },
	[19] = { Cost = 2_300_000_000 },
	[20] = { Cost = 36_000_000_000 }, -- WALL
	[21] = { Cost = 43_000_000_000 },
	[22] = { Cost = 51_000_000_000 },
	[23] = { Cost = 62_000_000_000 },
	[24] = { Cost = 74_000_000_000 },
	[25] = { Cost = 1_300_000_000_000 }, -- WALL
	[26] = { Cost = 1_600_000_000_000 },
	[27] = { Cost = 1_900_000_000_000 },
	[28] = { Cost = 2_200_000_000_000 },
	[29] = { Cost = 2_700_000_000_000 },
	[30] = { Cost = 54_000_000_000_000 }, -- WALL
	[31] = { Cost = 65_000_000_000_000 },
	[32] = { Cost = 78_000_000_000_000 },
	[33] = { Cost = 93_000_000_000_000 },
	[34] = { Cost = 110_000_000_000_000 },
	[35] = { Cost = 2_600_000_000_000_000 }, -- WALL
	[36] = { Cost = 3_100_000_000_000_000 },
	[37] = { Cost = 3_700_000_000_000_000 },
	[38] = { Cost = 4_500_000_000_000_000 },
	[39] = { Cost = 5_400_000_000_000_000 },
	[40] = { Cost = 140_000_000_000_000_000 }, -- WALL
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
