local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local Orb = require(script.Parent:WaitForChild("Orb"))
local Knit = require(External:WaitForChild("Knit"))

local OrbService = {
	Name = "OrbService",
	Client = {},
	_ReplicationService = nil,
	_RewardsService = nil,
	_PlayerOrbs = {}
}

function OrbService:KnitStart()
	self._ReplicationService = require(ServerScriptService.Services.Replication.ReplicationService)
	self._RewardsService = require(ServerScriptService.Services.Rewards.RewardsService)
end

function OrbService:OnPlayerAdded(player)
	self._PlayerOrbs[player] = {}
end

function OrbService:OnPlayerRemoving(player)
	self:DestroyAllOrbsForPlayer(player)

	self._PlayerOrbs[player] = nil
end

function OrbService:AddOrbForPlayer(player, metadata, claimedCallback)
	metadata = metadata or {}

	local orbs = self._PlayerOrbs[player]
	if not orbs then return end

	local newOrb = Orb.new(self._ReplicationService, metadata)
	newOrb.DestroyedSignal:Connect(function()
		local index = table.find(self._PlayerOrbs[player] or {}, newOrb)
		if index then
			table.remove(self._PlayerOrbs[player] or {}, index)
		end
	end)

	newOrb.Claimed:Connect(function()
		if claimedCallback then
			claimedCallback()
		end
	end)

	table.insert(self._PlayerOrbs[player], newOrb)

	newOrb:ReplicateTo({ player })

	return newOrb
end

function OrbService:_GetOrbForPlayer(player, guid)
	for index, orb in pairs(self._PlayerOrbs[player] or {}) do
		if orb:GetGuid() == guid then
			return orb, index
		end
	end
end

function OrbService:_ClaimOrbForPlayer(player, guid)
	local orb = self:_GetOrbForPlayer(player, guid)
	if not orb then
		return
	end

	local metadata = orb:GetMetadata()
	local rewardType = metadata.RewardType
	local reward = metadata.Reward

	if rewardType and reward then
		self._RewardsService:RewardPlayer(player, rewardType, reward)
	end

	orb.Claimed:Fire()

	orb:Destroy()
end

function OrbService:DestroyAllOrbsForPlayer(player)
	local orbs = {}
	for _, orb in pairs(self._PlayerOrbs[player] or {}) do
		table.insert(orbs, orb)
	end

	for _, orb in pairs(orbs) do
		orb:Destroy()
	end
end

function OrbService.Client:ClaimOrbForPlayer(player, guid)
	if type(guid) ~= "string" then
		return
	end

	self.Server:_ClaimOrbForPlayer(player, guid)
end

return OrbService