local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local BoostsEnum = require(Enums:WaitForChild("Boosts"))
local Knit = require(External:WaitForChild("Knit"))

local FriendsService = {
	Name = "FriendsService",
	Client = {
		Friends = Knit.CreateProperty(nil)
	},
	_BoostsService = nil,
}

function FriendsService:KnitStart()
	self._BoostsService = require(ServerScriptService.Services.Boosts.BoostsService)
end

function FriendsService:OnPlayerAdded(player)
	self.Client.Friends:SetFor(player, {})

	self:_CheckFriendsInServer(player)
end

function FriendsService:OnPlayerRemoving(player)
	self:_RemoveFromFriends(player)
	self._BoostsService:RemoveBoostForPlayer(player, BoostsEnum.FriendBoost)
end

function FriendsService:_CheckFriendsInServer(player)
	task.spawn(function()
		for _, otherPlayer in pairs(Players:GetPlayers()) do
			if otherPlayer == player then continue end

			-- Check if they are friends
			local areFriends = self:AreFriends(player, otherPlayer)
			if not Players:IsAncestorOf(player) then return end
			if not Players:IsAncestorOf(otherPlayer) then continue end
			if not areFriends then continue end

			-- If they are friends, put the other player into the players friend
			-- cache
			local friends = self.Client.Friends:GetFor(player)
			if not table.find(friends, otherPlayer) then
				table.insert(friends, otherPlayer)
				self.Client.Friends:SetFor(player, friends)
				self:_UpdateFriendsBoostForPlayer(player)
			end

			-- Also place the player in other players friend cache
			local otherFriends = self.Client.Friends:GetFor(otherPlayer)
			if not otherFriends then continue end
			if not table.find(otherFriends, player) then
				table.insert(otherFriends, player)
				self.Client.Friends:SetFor(otherPlayer, otherFriends)
				self:_UpdateFriendsBoostForPlayer(otherPlayer)
			end
		end
	end)
end

function FriendsService:_RemoveFromFriends(player)
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer == player then continue end

		local otherFriends = self.Client.Friends:GetFor(otherPlayer)
		if not otherFriends then continue end

		local index = table.find(otherFriends, player)
		if index then
			table.remove(otherFriends, index)
			self.Client.Friends:SetFor(otherPlayer, otherFriends)
			self:_UpdateFriendsBoostForPlayer(otherPlayer)
		end
	end
end

function FriendsService:_UpdateFriendsBoostForPlayer(player)
	local friends = self.Client.Friends:GetFor(player) or {}

	local boostLevel = #friends

	if boostLevel <= 0 then
		self._BoostsService:RemoveBoostForPlayer(player, BoostsEnum.FriendBoost)
		return
	end

	local boost = self._BoostsService:GetBoostOfIdForPlayer(player, BoostsEnum.FriendBoost)
	if not boost then
		self._BoostsService:AddBoostForPlayer(player, {
			Id = BoostsEnum.FriendBoost,
			Level = boostLevel
		})
	else
		self._BoostsService:UpdateBoostOfId(player, BoostsEnum.FriendBoost, {
			Level = boostLevel
		})
	end
end

function FriendsService:GetPlayerFriends(player)
	return self.Client.Friends:GetFor(player) or {}
end

function FriendsService:AreFriends(player, otherPlayer)
	local friends = self:GetPlayerFriends(player)
	if table.find(friends, otherPlayer) then
		return true
	end

	local otherFriends = self:GetPlayerFriends(otherPlayer)
	if table.find(otherFriends, player) then
		return true
	end

	local success, areFriends = pcall(function()
		return player:IsFriendsWith(otherPlayer.UserId)
	end)

	if not success then
		return false
	end

	return areFriends
end

return FriendsService