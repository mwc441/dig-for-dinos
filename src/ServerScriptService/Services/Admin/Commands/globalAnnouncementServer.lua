local ServerScriptService = game:GetService("ServerScriptService")

local RewardService = require(ServerScriptService.Services.Rewards.RewardsService)

return function(context, message: string, color)
	local player = context.Executor :: Player

	local verifiedIcon = ""
	local nameText = string.format("%s%s", player.DisplayName, verifiedIcon)

	local finalMessage = string.format("<font color=\"#3498eb\">%s:</font> %s", nameText, message)
	RewardService:MakeCrossServerAnnouncement(finalMessage, color or Color3.fromRGB(255, 255, 255))
end