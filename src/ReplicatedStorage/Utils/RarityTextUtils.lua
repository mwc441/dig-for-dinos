local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local External = ReplicatedStorage:WaitForChild("External")
local EasyVisuals = require(External:WaitForChild("EasyVisuals"))
local RaritiesEnum = require(Enums:WaitForChild("Rarities"))

local RarityColorUtils = {}

local RARITY_COLORS = {
	[RaritiesEnum.Common] = Color3.fromRGB(190, 190, 190),
	[RaritiesEnum.Uncommon] = Color3.fromRGB(84, 255, 118),
	[RaritiesEnum.Rare] = Color3.fromRGB(67, 166, 255),
	[RaritiesEnum.Epic] = Color3.fromRGB(180, 82, 255),
	[RaritiesEnum.Legendary] = Color3.fromRGB(255, 198, 66),
	[RaritiesEnum.Mythical] = Color3.fromRGB(4, 255, 242),
	[RaritiesEnum.Secret] = Color3.fromRGB(28, 28, 28)
}

function RarityColorUtils.SetColor(textLabel: TextLabel, rarity: string?)
	local color = RARITY_COLORS[rarity]
	if color then
		textLabel.TextColor3 = color
	end

	if rarity == RaritiesEnum.Mythical then
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		EasyVisuals.new(textLabel, "Rainbow", 0.5)
	elseif rarity == RaritiesEnum.Secret then
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		local uiStroke = textLabel:FindFirstChildWhichIsA("UIStroke")
		EasyVisuals.new(textLabel, "Zebra", 1, uiStroke and uiStroke.Thickness or 1)
	end
end

return RarityColorUtils
