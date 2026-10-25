local ServerScriptService = game:GetService("ServerScriptService")
local RewardService = require(ServerScriptService.Services.Rewards.RewardsService)

return function(context, rewardType, reward, message: string?, color)
	if message then
		local player = context.Executor :: Player
		local verifiedIcon = ""
		local nameText = string.format("%s%s", player.DisplayName, verifiedIcon)

		local finalMessage = string.format("<font color=\"#3498eb\">%s:</font> %s", nameText, message)
		message = finalMessage
	end

	RewardService:GiveCrossServerReward(rewardType, reward, message, color)
end
