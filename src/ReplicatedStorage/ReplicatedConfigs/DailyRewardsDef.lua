local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))

local DailyRewardsDef = {}

DailyRewardsDef.Table = {
	[1] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 100
			}
		}
	},

	[2] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 100
			}
		}
	},

	[3] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 100
			}
		}
	},

	[4] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 100
			}
		}
	},

	[5] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 100
			}
		}
	},

	[6] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 100
			}
		}
	},

	[7] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 200
			},

			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 500
			}
		}
	}
}

function DailyRewardsDef.GetAllRewards()
	return DailyRewardsDef.Table
end

function DailyRewardsDef.GetDayInfo(day)
	return DailyRewardsDef.Table[day]
end

return DailyRewardsDef