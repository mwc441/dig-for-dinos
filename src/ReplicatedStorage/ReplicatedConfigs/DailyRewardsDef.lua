local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))

local DailyRewardsDef = {}

-- these are tuned to where an avg player is on each day (most kids play like 15-20 min a day). should feel worth coming back for
-- day 4 and 7 should also give dinos once lollypop adds that (rare on 4, epic/legendary on 7). long term these should scale with progress or give timed boosts
DailyRewardsDef.Table = {
	[1] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 1000,
			},
		},
	},

	[2] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.DigPower,
				Reward = 10_000,
			},
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 250_000,
			},
		},
	},

	[3] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 1_000_000,
			},
		},
	},

	[4] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 3_000_000,
			},
		},
	},

	[5] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.DigPower,
				Reward = 40_000,
			},
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 8_000_000,
			},
		},
	},

	[6] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 25_000_000,
			},
		},
	},

	[7] = {
		Rewards = {
			{
				RewardType = PlayerStatsEnum.DigPower,
				Reward = 100_000,
			},
			{
				RewardType = PlayerStatsEnum.Cash,
				Reward = 100_000_000,
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
