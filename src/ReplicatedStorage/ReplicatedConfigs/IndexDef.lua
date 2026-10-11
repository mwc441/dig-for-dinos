local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local MutationsEnum = require(Enums:WaitForChild("Mutations"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local BoostsEnum = require(Enums:WaitForChild("Boosts"))

local IndexDef = {}

IndexDef.Table = {
	[MutationsEnum.Normal] = {
		Name = "Normal",
		Order = 1,
		Icon = "rbxassetid://82633035815108",
		Boost = BoostsEnum.IndexCoinBoost,
		Levels = {
			[1] = {
				Required = 1,
				Rewards = {
					[PlayerStatsEnum.Cash] = 500
				}
			}
		}
	},

	[MutationsEnum.Flame] = {
		Name = "Flame",
		Order = 2,
		Icon = "rbxassetid://109377335165115",
		Boost = BoostsEnum.IndexCoinBoost,
		Levels = {
			[1] = {
				Required = 1,
				Rewards = {
					[PlayerStatsEnum.Cash] = 1000
				}
			}
		}
	},

	[MutationsEnum.Gold] = {
		Name = "Gold",
		Order = 3,
		Icon = "rbxassetid://76338452583696",
		Boost = BoostsEnum.IndexCoinBoost,
		Levels = {
			[1] = {
				Required = 1,
				Rewards = {
					[PlayerStatsEnum.Cash] = 1500
				}
			}
		}
	},

	[MutationsEnum.Void] = {
		Name = "Void",
		Order = 4,
		Icon = "rbxassetid://134758484439921",
		Boost = BoostsEnum.IndexCoinBoost,
		Levels = {
			[1] = {
				Required = 1,
				Rewards = {
					[PlayerStatsEnum.Cash] = 2500
				}
			}
		}
	}
}

function IndexDef.GetAllIndexes()
	return IndexDef.Table
end

function IndexDef.GetIndexInfo(id)
	return IndexDef.Table[id]
end

function IndexDef.GetLevelInfoForIndex(id, level)
	local info = IndexDef.GetIndexInfo(id)
	if not info then return end

	return info.Levels[level]
end

return IndexDef
