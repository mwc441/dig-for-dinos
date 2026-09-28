local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer

local External = ReplicatedStorage:WaitForChild("External")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local BoostTypesEnum = require(Enums:WaitForChild("BoostTypes"))
local Orb = require(script.Parent:WaitForChild("Orb"))
local Knit = require(External:WaitForChild("Knit"))
local Signal = require(External:WaitForChild("Signal"))

local ORB_PICKUP_RADIUS_BASE = 10

local OrbController = {
	Name = "OrbController",
	_ReplicationController = nil,
	_BoostController = nil,
	_OrbService = nil,
	_Orbs = {},
	_OrbClaimGui = nil,
	_OrbTemplateTweens = {},
	_OrbTemplateTasks = {},
	_OrbTemplateAmounts = {},
	_OrbClaimPart = nil,
	OrbClaimed = Signal.new()
}

function OrbController:KnitStart()
	self._ReplicationController = require(ReplicatedStorage.Controllers.Replication.ReplicationController)
	self._BoostController = require(ReplicatedStorage.Controllers.Boosts.BoostController)
	self._OrbService = Knit.GetService("OrbService")

	for _, replicationData in pairs(self._ReplicationController:GetReplicatorsOfType("Orb")) do
		self:_CreateNewOrb(replicationData)
	end

	self._ReplicationController.ReplicatorReplicatedSignal:Connect(function(replicationData)
		if replicationData.Type == "Orb" then
			self:_CreateNewOrb(replicationData)
		end
	end)

	self._ReplicationController.ReplicatorDereplicatedSignal:Connect(function(guid)
		self:_DestroyOrb(guid)
	end)

	self:_CheckRangeForOrbs()
end

function OrbController:_CreateNewOrb(replicationData)
	local metadata = replicationData.Metadata or {}
	local cframe = Player.Character:GetPivot()

	local newOrb = Orb.new(self, replicationData, cframe)

	newOrb.OrbClaimedSignal:Connect(function(guid)
		self._OrbService:ClaimOrbForPlayer(guid)
		self.OrbClaimed:Fire(metadata.RewardType, metadata.Reward)
	end)

	self._Orbs[replicationData.Guid] = newOrb
end

function OrbController:_DestroyOrb(guid)
	local orb = self._Orbs[guid]
	if orb then
		orb:Destroy()
	end

	self._Orbs[guid] = nil
end

function OrbController:_GetPickupRadius()
	local basePickupRadius = ORB_PICKUP_RADIUS_BASE

	return basePickupRadius
end

function OrbController:_CheckRangeForOrbs()
	RunService.Heartbeat:Connect(function()
		local character = Player.Character
		if not character then
			return
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			return
		end

		for _, orb in pairs(self._Orbs) do
			local model = orb:GetModel()
			if not model then
				continue
			end

			local distance = (rootPart.Position - model:GetPivot().Position).Magnitude
			if distance <= self:_GetPickupRadius() then
				orb:AlignPositionToCharacter()
			end
		end
	end)
end

return OrbController