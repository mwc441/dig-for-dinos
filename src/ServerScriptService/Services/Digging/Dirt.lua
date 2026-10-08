local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local Replication = ServerScriptService.Services:WaitForChild("Replication")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Signal = require(External:WaitForChild("Signal"))
local Replicator = require(Replication:WaitForChild("Replicator"))
local DirtDef = require(ReplicatedConfigs:WaitForChild("DirtDef"))
local Trove = require(External:WaitForChild("Trove"))

local Dirt = {}
Dirt.__index = Dirt
setmetatable(Dirt, Replicator)

function Dirt.new(replicationService, cframe, dirtId, scale)
	local dirtInfo = DirtDef.GetDirtInfo(dirtId)
	assert(dirtInfo, "Unknown DirtId: " .. tostring(dirtId))

	local self = Replicator.new(replicationService)
	setmetatable(self, Dirt)

	self._Trove = Trove.new()

	self._Type = "Dirt"
	self._CFrame = cframe
	self._DirtId = dirtId
	self._Scale = scale
	self._TotalHealth = dirtInfo.TotalHealth
	self._Health = dirtInfo.TotalHealth

	self.DestroyedSignal = Signal.new()
	self._Trove:Add(self.DestroyedSignal)

	-- Self destruct so spawns disappear and spawn new ones naturally
	self:_SetupSelfDestruction()

	return self
end

function Dirt:GetCFrame()
	return self._CFrame
end

function Dirt:GetDirtId()
	return self._DirtId
end

function Dirt:GetScale()
	return self._Scale
end

function Dirt:GetHealth()
	return self._Health
end

function Dirt:GetTotalHealth()
	return self._TotalHealth
end

function Dirt:GetReplicationData()
	local replicationData = Replicator.GetReplicationData(self)
	replicationData.CFrame = self._CFrame
	replicationData.DirtId = self._DirtId
	replicationData.Scale = self._Scale
	replicationData.Health = self._Health
	replicationData.TotalHealth = self._TotalHealth
	replicationData.LastHitUserId = self._LastHitUserId
	replicationData.LastHitPredictionId = self._LastHitPredictionId

	return replicationData
end

function Dirt:_SetupSelfDestruction()
	self._Trove:Remove(self._SelfDestructTask)
	self._SelfDestructTask = task.delay(3 * 60, function()
		self:Destroy()
	end)
	self._Trove:Add(self._SelfDestructTask)
end

function Dirt:Damage(amount, userId, predictionId)
	if self._Destroyed or typeof(amount) ~= "number" or amount <= 0 or amount ~= amount then
		return
	end

	local previousHealth = self._Health
	local newHealth = math.max(0, self._Health - amount)
	if previousHealth == newHealth then return end

	self._Health = newHealth

	self._LastHitUserId = userId
	self._LastHitPredictionId = predictionId

	self:_SetupSelfDestruction()

	self:Update()

	if self._Health == 0 then
		self:Destroy()
	end

	return self._Health
end

function Dirt:Destroy()
	if self._Destroyed then
		return
	end

	self.DestroyedSignal:Fire()
	Replicator.Destroy(self)

	self._Trove:Clean()
end

return Dirt
