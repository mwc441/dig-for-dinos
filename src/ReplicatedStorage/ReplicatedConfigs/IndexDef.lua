local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local MutationsEnum = require(Enums:WaitForChild("Mutations"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local BoostsEnum = require(Enums:WaitForChild("Boosts"))

local IndexDef = {}

-- every level u claim gives +5% cash (BoostsDef index boosts). 33 dinos total, go catch em all or whatever
IndexDef.Table = {
	[MutationsEnum.Normal] = {
		Name = "Normal",
		Order = 1,
		Icon = "rbxassetid://82140004257721",
		Boost = BoostsEnum.NormalIndexCashBoost,
		Levels = {
			[1] = {
				Required = 5,
				Rewards = {
					[PlayerStatsEnum.Cash] = 500,
				},
			},
			[2] = {
				Required = 10,
				Rewards = {
					[PlayerStatsEnum.Cash] = 5_000,
				},
			},
			[3] = {
				Required = 20,
				Rewards = {
					[PlayerStatsEnum.Cash] = 500_000,
				},
			},
			[4] = {
				Required = 33,
				Rewards = {
					[PlayerStatsEnum.Cash] = 50_000_000,
				},
			},
		},
	},

	[MutationsEnum.Gold] = {
		Name = "Gold",
		Order = 2,
		Icon = "rbxassetid://97567301734284",
		Boost = BoostsEnum.GoldIndexCashBoost,
		Levels = {
			[1] = {
				Required = 1,
				Rewards = {
					[PlayerStatsEnum.Cash] = 2_000,
				},
			},
			[2] = {
				Required = 5,
				Rewards = {
					[PlayerStatsEnum.Cash] = 50_000,
				},
			},
			[3] = {
				Required = 15,
				Rewards = {
					[PlayerStatsEnum.Cash] = 5_000_000,
				},
			},
			[4] = {
				Required = 33,
				Rewards = {
					[PlayerStatsEnum.Cash] = 500_000_000,
				},
			},
		},
	},

	[MutationsEnum.Void] = {
		Name = "Void",
		Order = 3,
		Icon = "rbxassetid://108997451206251",
		Boost = BoostsEnum.VoidIndexCashBoost,
		Levels = {
			[1] = {
				Required = 1,
				Rewards = {
					[PlayerStatsEnum.Cash] = 4_000,
				},
			},
			[2] = {
				Required = 5,
				Rewards = {
					[PlayerStatsEnum.Cash] = 100_000,
				},
			},
			[3] = {
				Required = 15,
				Rewards = {
					[PlayerStatsEnum.Cash] = 10_000_000,
				},
			},
			[4] = {
				Required = 33,
				Rewards = {
					[PlayerStatsEnum.Cash] = 1_000_000_000,
				},
			},
		},
	},

	[MutationsEnum.Flame] = {
		Name = "Flame",
		Order = 4,
		Icon = "rbxassetid://99732016857925",
		Boost = BoostsEnum.FlameIndexCashBoost,
		Levels = {
			[1] = {
				Required = 1,
				Rewards = {
					[PlayerStatsEnum.Cash] = 10_000,
				},
			},
			[2] = {
				Required = 5,
				Rewards = {
					[PlayerStatsEnum.Cash] = 250_000,
				},
			},
			[3] = {
				Required = 15,
				Rewards = {
					[PlayerStatsEnum.Cash] = 25_000_000,
				},
			},
			[4] = {
				Required = 33,
				Rewards = {
					[PlayerStatsEnum.Cash] = 2_500_000_000,
				},
			},
		},
	},
}

function IndexDef.GetAllIndexes()
	return IndexDef.Table
end

function IndexDef.GetIndexInfo(id)
	return IndexDef.Table[id]
end

function IndexDef.GetLevelInfoForIndex(id, level)
	local info = IndexDef.GetIndexInfo(id)
	if not info then
		return
	end

	return info.Levels[level]
end

return IndexDef
