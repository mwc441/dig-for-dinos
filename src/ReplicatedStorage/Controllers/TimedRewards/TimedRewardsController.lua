local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GroupService = game:GetService("GroupService")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local GroupRewardSound = Sounds:WaitForChild("GroupReward")
local ErrorSound = Sounds:WaitForChild("Error")
local External = ReplicatedStorage:WaitForChild("External")
local Components = ReplicatedStorage:WaitForChild("Components")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local Knit = require(External:WaitForChild("Knit"))

local TimedRewardsController = {
	Name = "TimedRewardsController",
	_TimedRewardsService = nil
}

function TimedRewardsController:KnitStart()
	self._GroupRewardComponent = require(Components.GroupReward)
	self._TimedRewardsService = Knit.GetService("TimedRewardsService")

	self:_SetupGroupRewards()
end

function TimedRewardsController:_SetupGroupRewards()
	for _, groupReward in pairs(self._GroupRewardComponent:GetAll()) do
		self:_SetupGroupReward(groupReward)
	end

	self._GroupRewardComponent.Started:Connect(function(groupReward)
		self:_SetupGroupReward(groupReward)
	end)
end

function TimedRewardsController:_SetupGroupReward(groupReward)
	groupReward.Interacted:Connect(function()
		local success, isInGroup = pcall(function()
			return Player:IsInGroupAsync(Constants.GroupId)
		end)
		if not success then return end

		if not isInGroup then
			local success2, result = pcall(function()
				return GroupService:PromptJoinAsync(Constants.GroupId)
			end)
			if not success2 then return end

			if result == Enum.GroupMembershipStatus.Joined then
				self:_ClaimGroupReward()
			end
		else
			self:_ClaimGroupReward()
		end
	end)
end

function TimedRewardsController:_ClaimGroupReward()
	self._TimedRewardsService:ClaimGroupReward():andThen(function(success)
		if success then
			GroupRewardSound:Play()
		else
			ErrorSound:Play()
		end
	end)
end

return TimedRewardsController