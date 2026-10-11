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

function RarityColorUtils.GetColor(rarity: string) : Color3
	return RARITY_COLORS[rarity] or Color3.fromRGB(255, 255, 255)
end

function RarityColorUtils.SetTextColor(textLabel: TextLabel, rarity: string)
	local color = RARITY_COLORS[rarity]
	if color then
		textLabel.TextColor3 = color
	end

	if rarity == RaritiesEnum.Mythical then
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		return EasyVisuals.new(textLabel, "Rainbow", 0.5)
	elseif rarity == RaritiesEnum.Secret then
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		local uiStroke = textLabel:FindFirstChildWhichIsA("UIStroke")
		return EasyVisuals.new(textLabel, "Zebra", 1, uiStroke and uiStroke.Thickness or 1)
	end
end

function RarityColorUtils.SetImageColor(imageLabel: ImageLabel, rarity: string)
	local color = RARITY_COLORS[rarity]
	if color then
		imageLabel.ImageColor3 = color
	end

	if rarity == RaritiesEnum.Mythical then
		imageLabel.ImageColor3 = Color3.fromRGB(255, 255, 255)
		return EasyVisuals.new(imageLabel, "Rainbow", 0.5)
	elseif rarity == RaritiesEnum.Secret then
		imageLabel.ImageColor3 = Color3.fromRGB(255, 255, 255)
		local uiStroke = imageLabel:FindFirstChildWhichIsA("UIStroke")
		return EasyVisuals.new(imageLabel, "Zebra", 1, uiStroke and uiStroke.Thickness or 1)
	end
end

function RarityColorUtils.SetColor(guiObject: GuiObject, rarity: string)
	if guiObject:IsA("TextLabel") then
		return RarityColorUtils.SetTextColor(guiObject, rarity)
	elseif guiObject:IsA("ImageLabel") then
		return RarityColorUtils.SetImageColor(guiObject, rarity)
	end
end

return RarityColorUtils
