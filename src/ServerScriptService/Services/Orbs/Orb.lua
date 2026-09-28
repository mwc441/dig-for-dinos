local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService:WaitForChild("Services")
local Replication = Services:WaitForChild("Replication")
local External = ReplicatedStorage:WaitForChild("External")
local Signal = require(External:WaitForChild("Signal"))
local Trove = require(External:WaitForChild("Trove"))
local Replicator = require(Replication:WaitForChild("Replicator"))

local Orb = {}
Orb.__index = Orb
setmetatable(Orb, Replicator)

function Orb.new(replicationService, metadata)
	local self = Replicator.new(replicationService)
	setmetatable(self, Orb)

	self._Type = "Orb"
	self._Metadata = metadata

	self._Trove = Trove.new()

	self.Claimed = Signal.new()
	self._Trove:Add(self.Claimed)

	self.DestroyedSignal = Signal.new()
	self._Trove:Add(self.DestroyedSignal)

	self._Trove:Add(task.delay(5 * 60, function()
		self:Destroy()
	end))

	return self
end

function Orb:GetMetadata()
	return self._Metadata
end

function Orb:GetReplicationData()
	local replicationData = Replicator.GetReplicationData(self)
	replicationData.Metadata = self._Metadata

	return replicationData
end

function Orb:Destroy()
	self.DestroyedSignal:Fire()

	Replicator.Destroy(self)

	self._Trove:Clean()
end

return Orb