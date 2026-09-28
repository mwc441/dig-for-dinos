local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Signal = require(External:WaitForChild("Signal"))
local Knit = require(External:WaitForChild("Knit"))

local ReplicationController = {
	Name = "ReplicationController",
	_ReplicationService = nil,
	_Replicators = {},
	ReplicatorReplicatedSignal = Signal.new(),
	ReplicatorUpdatedSignal = Signal.new(),
	ReplicatorEventSignal = Signal.new(),
	ReplicatorDereplicatedSignal = Signal.new()
}

function ReplicationController:KnitStart()
	self._ReplicationService = Knit.GetService("ReplicationService")

	self._ReplicationService.ReplicatorReplicated:Connect(function(replicationData)
		local guid = replicationData.Guid
		if not guid then
			return
		end

		local replicatorType = replicationData.Type
		if not replicatorType then
			return
		end

		self._Replicators[guid] = replicationData

		self.ReplicatorReplicatedSignal:Fire(replicationData)
	end)

	self._ReplicationService.ReplicatorUpdated:Connect(function(replicationData)
		local guid = replicationData.Guid
		if not guid then
			return
		end

		self._Replicators[guid] = replicationData

		self.ReplicatorUpdatedSignal:Fire(replicationData)
	end)

	self._ReplicationService.ReplicatorEvent:Connect(function(guid, eventName, ...)
		local replicationData = self._Replicators[guid]
		if not replicationData then
			return
		end

		self.ReplicatorEventSignal:Fire(guid, eventName, ...)
	end)

	self._ReplicationService.ReplicatorDereplicated:Connect(function(guid)
		self._Replicators[guid] = nil

		self.ReplicatorDereplicatedSignal:Fire(guid)
	end)
end

function ReplicationController:GetReplicators()
	return self._Replicators
end

function ReplicationController:GetReplicatorsOfType(replicatorType)
	local replicatorsOfType = {}
	for _, replicationData in pairs(self._Replicators) do
		if replicationData.Type == replicatorType then
			table.insert(replicatorsOfType, replicationData)
		end
	end

	return replicatorsOfType
end

function ReplicationController:FireEventToServer(guid, eventName, ...)
	self._ReplicationService.ReplicatorEvent:Fire(guid, eventName, ...)
end

return ReplicationController