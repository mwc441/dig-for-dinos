local GroupService = game:GetService("GroupService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Player = Players.LocalPlayer

local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local Knit = require(External:WaitForChild("Knit"))

local ChatController = {
	Name = "ChatController",
	_LeaderboardController = nil
}

function ChatController:KnitInit()
	TextChatService.OnIncomingMessage = function(message)
		local properties = Instance.new("TextChatMessageProperties")

		properties.PrefixText = message.PrefixText

		if message.TextSource then
			local player = Players:GetPlayerByUserId(message.TextSource.UserId)
			if not player then
				return properties
			end

			local isVip = player:GetAttribute("Vip")

			properties.PrefixText = " " .. properties.PrefixText

			if isVip then
				properties.PrefixText = "<font color='#fdce10'>[VIP]</font>" .. properties.PrefixText
			end

			local leaderboardTags = self._LeaderboardController:GetChatTagsForPlayer(player)
			if leaderboardTags ~= "" then
				properties.PrefixText = leaderboardTags .. properties.PrefixText
			end

			local highestRank = UtilFunctions.GetHighestGroupRankForPlayer(player, Constants.GroupId)

			if highestRank then
				local groupRankInfo = Constants.GroupRanks[highestRank]
				if groupRankInfo then
					properties.PrefixText = string.format("<font color='#%s'>[%s]</font>", groupRankInfo.Color, groupRankInfo.Rank) .. properties.PrefixText
				end
			end
		end

		if message.Metadata ~= "" then
			local text = message.Text
			local metadata
			pcall(function()
				metadata = HttpService:JSONDecode(message.Metadata)
			end)

			if not metadata then
				return properties
			end

			local font = metadata.Font
			local color = metadata.Color
			local textSize = metadata.TextSize

			local fontString = "<font"
			if color then
				fontString ..= " color=\"#" .. color .."\""
			end

			if font then
				local fontNameString
				if typeof(font) == "EnumItem" then
					fontNameString = font.Name
				else
					fontNameString = tostring(font)
				end
				fontString ..= " face=\"" .. fontNameString .. "\""
			end

			if textSize then
				fontString ..= " size=\"" .. textSize .. "\""
			end
			fontString ..= ">"

			text = fontString .. text .. "</font>"

			properties.Text = text
		end

		return properties
	end

	-- Hide chat bar in channels that player cant speak in
	local inputBarConfig = TextChatService.ChatInputBarConfiguration :: ChatInputBarConfiguration
	inputBarConfig:GetPropertyChangedSignal("TargetTextChannel"):Connect(function()
		local currentChannel = inputBarConfig.TargetTextChannel
		if not currentChannel then return end

		local textSource = currentChannel:FindFirstChild(Player.DisplayName)
		if not textSource then return end

		inputBarConfig.Enabled = textSource.CanSend
	end)
end

function ChatController:KnitStart()
	self._LeaderboardController = require(ReplicatedStorage.Controllers.Leaderboards.LeaderboardController)
end

return ChatController