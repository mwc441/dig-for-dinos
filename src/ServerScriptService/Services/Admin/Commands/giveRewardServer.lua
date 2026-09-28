local ServerScriptService = game:GetService("ServerScriptService")
local RewardService = require(ServerScriptService.Services.Rewards.RewardsService)

return function(context, rewardType, reward, player)
	player = player or context.Executor
	RewardService:RewardPlayer(player, rewardType, reward, true)
end