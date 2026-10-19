local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local AnnouncementSound = Sounds:WaitForChild("Announcement")
local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local BigNumbers = require(External:WaitForChild("BigNumbers"))
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local ItemDef = require(ReplicatedConfigs:WaitForChild("ItemDef"))
local Knit = require(External:WaitForChild("Knit"))

local POTENTIAL_REWARD_COLORS = {
	Color3.fromRGB(255, 255, 0),

	Color3.fromRGB(46, 252, 255),

	Color3.fromRGB(253, 31, 253),

	Color3.fromRGB(53, 255, 87)
}
local QUEUE_TIME = 0.5

local RewardsController = {
	Name = "RewardsController",
	_RewardsService = nil,
	_MessageQueue = {},
	_OriginalTexts = {},
	_LastMessageMade = 0,
	_RewardQueue = {},
	_RewardTotals = {},
	_LastRewardMade = 0
}

function RewardsController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local messagesFrame = mainGui:WaitForChild("MessagesFrame")
	local rewardsFrame = mainGui:WaitForChild("RewardsFrame")
	local announcementsFrame = mainGui:WaitForChild("AnnouncementsFrame")
	self._Gui = {
		RewardsFrame = rewardsFrame,
		RewardTemplate = rewardsFrame:WaitForChild("Templates"):WaitForChild("RewardTemplate"),
		MessageFrame = messagesFrame,
		MessageTemplate = messagesFrame:WaitForChild("Templates"):WaitForChild("MessageTemplate"),
		AnnouncementsFrame = announcementsFrame,
		AnnouncementTemplate = announcementsFrame:WaitForChild("Templates"):WaitForChild("AnnouncementTemplate")
	}
end

function RewardsController:KnitStart()
	self._RewardsService = Knit.GetService("RewardsService")

	local channels = TextChatService:WaitForChild("TextChannels")
	local globalChannel = channels:WaitForChild("Announcements") :: TextChannel
	local systemChannel = channels:WaitForChild("RBXGeneral") :: TextChannel
	self._GlobalTextChannel = globalChannel
	self._SystemTextChannel = systemChannel

	self:Start()

	self._RewardsService.MessageAnnounced:Connect(function(rewardsMessage, color)
		self:AnnounceMessage(rewardsMessage, color)
	end)

	self._RewardsService.SystemMessageAnnounced:Connect(function(rewardMessage, color)
		self:AnnounceSystemMessage(rewardMessage, color)
	end)

	self._RewardsService.GlobalMessageAnnounced:Connect(function(rewardMessage, color)
		self:AnnounceGlobalMessage(rewardMessage, color)
	end)

	self._RewardsService.AnnouncementMade:Connect(function(message, color)
		self:MakeAnnouncement(message, color)
	end)

	self._RewardsService.RewardShown:Connect(function(rewardType, reward)
		self:AnnounceReward(rewardType, reward)
	end)
end

function RewardsController:_ChooseRandomColor()
	local randomNumber = math.random(1, #POTENTIAL_REWARD_COLORS)
	return POTENTIAL_REWARD_COLORS[randomNumber]
end

function RewardsController:Start()
	self._Started = true

	if #self._MessageQueue >= 1 then
		self:_StartMessageQueue()
	end

	if #self._RewardQueue >= 1 then
		self:_StartRewardQueue()
	end
end

-- Make a message at the bottom of the screen
function RewardsController:AnnounceMessage(message, color)
	for _, queueTable in pairs(self._MessageQueue) do
		if queueTable.Message == message then
			return
		end
	end

	local messageIsAlreadyIn = false
	for _, template in pairs(self._Gui.MessageFrame:GetChildren()) do
		if not template:IsA("Frame") then
			continue
		end

		local originalText = self._OriginalTexts[template]
		if not originalText then
			continue
		end

		local totalTimes = template:GetAttribute("Times") or 1
		if originalText == message then
			messageIsAlreadyIn = true
			template.MessageText.Text = string.format("%s (x%d)", originalText, totalTimes + 1)
			template:SetAttribute("Times", totalTimes + 1)
			break
		end
	end

	if messageIsAlreadyIn then
		return
	end

	table.insert(self._MessageQueue, {
		Message = message,
		Color = color
	})

	if (#self._MessageQueue <= 1) and self._Started then
		self:_StartMessageQueue()
	end
end

-- Show item reward at right side of the screen
function RewardsController:AnnounceReward(rewardType, reward)
	local icon = self:GetIconFor(rewardType)
	if icon == "" then
		return
	end

	-- If theres a template already, edit the template and return
	for _, template in pairs(self._Gui.RewardsFrame:GetChildren()) do
		if not template:IsA("Frame") then
			continue
		end

		if template.Name == rewardType then
			local total = self._RewardTotals[template]

			self._RewardTotals[template] = total + reward
			template.RewardText.Text = string.format("+%s", BigNumbers.GetNumberDisplay(reward + total))

			return
		end
	end

	-- If theres already a similar reward in the queue, add to the queue table and return
	for _, rewardTable in pairs(self._RewardQueue) do
		if rewardTable.RewardType == rewardType then
			rewardTable.Reward = rewardTable.Reward + reward
			return
		end
	end

	table.insert(self._RewardQueue, {
		RewardType = rewardType,
		Reward = reward
	})

	if (#self._RewardQueue <= 1) and self._Started then
		self:_StartRewardQueue()
	end
end

function RewardsController:_StartMessageQueue()
	if self._MessageQueueHeartbeat then
		self._MessageQueueHeartbeat:Disconnect()
	end

	local total = os.clock() - self._LastMessageMade -- Check time since last message
	self._MessageQueueHeartbeat = RunService.Heartbeat:Connect(function(dt)
		if #self._MessageQueue <= 0 then
			-- if there are no more messages, just disconnect
			self._MessageQueueHeartbeat:Disconnect()
			self._MessageQueueHeartbeat = nil
			return
		end

		total += dt

		if total >= QUEUE_TIME then
			total = 0

			local message = self._MessageQueue[1]
			table.remove(self._MessageQueue, 1)

			self._LastMessageMade = os.clock()

			self:_AddMessageTemplate(message.Message, message.Color)
		end
	end)
end

function RewardsController:_StartRewardQueue()
	if self._RewardQueueHeartbeat then
		self._RewardQueueHeartbeat:Disconnect()
	end

	local total = os.clock() - self._LastRewardMade -- Check time since last
	self._RewardQueueHeartbeat = RunService.Heartbeat:Connect(function(dt)
		if #self._RewardQueue <= 0 then
			-- if there are no more messages, just disconnect
			self._RewardQueueHeartbeat:Disconnect()
			self._RewardQueueHeartbeat = nil
			return
		end

		total += dt

		if total >= QUEUE_TIME then
			total = 0

			local rewardTable = self._RewardQueue[1]
			table.remove(self._RewardQueue, 1)

			self._LastRewardMade = os.clock()

			self:_AddRewardTemplate(rewardTable.RewardType, rewardTable.Reward)
		end
	end)
end

function RewardsController:GetIconFor(rewardType)
	local itemInfo = ItemDef.GetItemInfo(rewardType)
	if itemInfo then
		return itemInfo.Icon or ""
	else
		return Constants.Icons[rewardType] or ""
	end
end

function RewardsController:_AddRewardTemplate(rewardType, reward)
	task.spawn(function()
		local totalTime = 3
		local newRewardTemplate = self._Gui.RewardTemplate:Clone()

		newRewardTemplate.Icon.Image = self:GetIconFor(rewardType) or ""

		newRewardTemplate.RewardText.Text = string.format("+%s", BigNumbers.GetNumberDisplay(reward))

		self._RewardTotals[newRewardTemplate] = reward

		newRewardTemplate.Name = rewardType or ""
		newRewardTemplate.Visible = true
		newRewardTemplate.Parent = self._Gui.RewardsFrame

		local animator = require(newRewardTemplate.Animator)
		local expandTrack = animator.Expand
		local disappearTrack = animator.Disappear

		expandTrack:Play()

		expandTrack.Completed:Wait()

		task.wait(totalTime)

		disappearTrack:Play()

		local connect
		connect = disappearTrack.Completed:Connect(function()
			connect:Disconnect()
			self._RewardTotals[newRewardTemplate] = nil
			newRewardTemplate:Destroy()
		end)
	end)
end

function RewardsController:_AddMessageTemplate(message, color)
	task.spawn(function()
		local time = 3
		local fadeTime = 0.25
		local growTime = 0.3

		local newMessageTemplate = self._Gui.MessageTemplate:Clone()
		color = color or self:_ChooseRandomColor()

		newMessageTemplate.MessageText.Text = message
		newMessageTemplate.MessageText.TextColor3 = color

		self._OriginalTexts[newMessageTemplate] = message
		newMessageTemplate.Visible = true
		newMessageTemplate.Parent = self._Gui.MessageFrame

		local scale = 0.75
		local originalSize = newMessageTemplate.Size
		local newSize = UDim2.new(
			originalSize.X.Scale * scale,
			originalSize.X.Offset * scale,
			originalSize.Y.Scale * scale,
			originalSize.Y.Offset * scale
		)

		newMessageTemplate.Size = newSize

		local tweenInfo = TweenInfo.new(growTime)
		local tween = TweenService:Create(newMessageTemplate, tweenInfo, {
			Size = originalSize
		})

		tween:Play()

		task.wait(time)

		tweenInfo = TweenInfo.new(fadeTime)
		tween = TweenService:Create(newMessageTemplate, tweenInfo, {
			Size = UDim2.fromScale(0, 0)
		})
		tween:Play()

		self._OriginalTexts[newMessageTemplate] = nil

		local connect
		connect = tween.Completed:Connect(function()
			connect:Disconnect()
			newMessageTemplate:Destroy()
		end)
	end)
end

-- Make a message inside the chat window
function RewardsController:AnnounceSystemMessage(rewardsMessage, color)
	if color then
		color = color:ToHex()
	else
		color = Color3.fromRGB(255,54,54):ToHex()
	end

	self._SystemTextChannel:DisplaySystemMessage(rewardsMessage, HttpService:JSONEncode({
		Color = color
	}))
end

function RewardsController:AnnounceGlobalMessage(rewardsMessage, color)
	if color then
		color = color:ToHex()
	else
		color = Color3.fromRGB(255,54,54):ToHex()
	end

	self._GlobalTextChannel:DisplaySystemMessage(rewardsMessage, HttpService:JSONEncode({
		Color = color
	}))
end

-- Put a message at the top of the screen
function RewardsController:MakeAnnouncement(message, color)
	task.spawn(function()
		local newAnnouncementTemplate = self._Gui.AnnouncementTemplate:Clone()
		newAnnouncementTemplate.MessageText.Text = message
		newAnnouncementTemplate.MessageText.TextColor3 = color or Color3.fromRGB(255, 255, 255)

		local oldSize = newAnnouncementTemplate.Size :: UDim2
		newAnnouncementTemplate.Size = UDim2.fromScale(0, 0)

		local tweenInfo = TweenInfo.new(0.25)
		local tween = TweenService:Create(newAnnouncementTemplate, tweenInfo, {
			Size = oldSize
		})

		tween:Play()

		local lowestLayoutOrder = 0
		for _, template in pairs(self._Gui.AnnouncementsFrame:GetChildren()) do
			if template:IsA(self._Gui.AnnouncementTemplate.ClassName) then
				if template.LayoutOrder < lowestLayoutOrder then
					lowestLayoutOrder = template.LayoutOrder
				end
			end
		end

		newAnnouncementTemplate.LayoutOrder = lowestLayoutOrder - 1
		newAnnouncementTemplate.Visible = true
		newAnnouncementTemplate.Parent = self._Gui.AnnouncementsFrame

		UtilFunctions.PlayCopyOfSound(AnnouncementSound)

		task.wait(5)

		tween = TweenService:Create(newAnnouncementTemplate, tweenInfo, {
			Size = UDim2.fromScale(0, 0)
		})
		tween:Play()
		tween.Completed:Once(function()
			newAnnouncementTemplate:Destroy()
		end)
	end)
end

return RewardsController