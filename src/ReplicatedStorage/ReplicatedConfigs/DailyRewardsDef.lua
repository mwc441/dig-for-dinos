local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))

local DailyRewardsDef = {}

-- mix of cash and dig power for now. day 4 and day 7 should get dinos once lollypop adds that (rare on 4, epic/legendary on 7)
DailyRewardsDef.Table = {
	[1] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 1_000,
			},
		},
	},

	[2] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.DigPower,
				Reward = 500,
			},
		},
	},

	[3] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 5_000,
			},
		},
	},

	[4] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 10_000,
			},
		},
	},

	[5] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.DigPower,
				Reward = 3_000,
			},
		},
	},

	[6] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 25_000,
			},
		},
	},

	[7] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.DigPower,
				Reward = 8_000,
			},

			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 50_000,
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
