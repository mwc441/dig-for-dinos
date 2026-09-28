local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local Player = Players.LocalPlayer

local External = ReplicatedStorage:WaitForChild("External")
local Knit = require(External:WaitForChild("Knit"))

local FriendController = {
	Name = "FriendController",
	_FriendsService = nil,
	_Friends = {}
}

function FriendController:KnitStart()
	self._FriendsService = Knit.GetService("FriendsService")

	local totalTime = 30
	local total = totalTime

	RunService.Heartbeat:Connect(function(dt)
		local previousTotal = total

		total += dt

		if (total > totalTime) and (previousTotal <= totalTime) then
			pcall(function()
				self:_UpdateAllFriends()
			end)

			total = 0
		end
	end)
end

function FriendController:AreFriends(player, otherPlayer)
	local success, areFriends = pcall(function()
		return player:IsFriendsWith(otherPlayer.UserId)
	end)

	if not success then
		return false
	end

	return areFriends
end

function FriendController:GetAllFriends()
	return self._Friends
end

function FriendController:_UpdateAllFriends()
	local function iterPageItems(pages)
		return coroutine.wrap(function()
			local pagenum = 1
			while true do
				for _, item in ipairs(pages:GetCurrentPage()) do
					coroutine.yield(item, pagenum)
				end
				if pages.IsFinished then
					break
				end

				pages:AdvanceToNextPageAsync()
				pagenum = pagenum + 1
			end
		end)
	end

	local friendPages = Players:GetFriendsAsync(Player.UserId)

	local friendIds = {}
	for item in iterPageItems(friendPages) do
		table.insert(friendIds, item.Id)
	end

	self._Friends = friendIds
end

function FriendController:InviteFriends()
	pcall(function()
		local canSendInvite = SocialService:CanSendGameInviteAsync(Player)
		if canSendInvite then
			local experienceInviteOptions = Instance.new("ExperienceInviteOptions")
			experienceInviteOptions.PromptMessage = "Invite friends for more Luck!"

			SocialService:PromptGameInvite(Player, experienceInviteOptions)
		end
	end)
end

return FriendController
