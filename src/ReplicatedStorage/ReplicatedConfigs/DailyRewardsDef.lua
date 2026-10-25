local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))

local DailyRewardsDef = {}

DailyRewardsDef.Table = {
	[1] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 100,
			},
		},
	},

	[2] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 250,
			},
		},
	},

	[3] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 500,
			},
		},
	},

	[4] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 1_000,
			},
		},
	},

	[5] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 2_500,
			},
		},
	},

	[6] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 5_000,
			},
		},
	},

	[7] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 10_000,
			},

			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 25_000,
			},
		},
	},
}

function DailyRewardsDef.GetAllRewards()
	return DailyRewardsDef.Table
end

function DailyRewardsDef.GetDayInfo(day)
	return DailyRewardsDef.Table[day]
end

return DailyRewardsDef
