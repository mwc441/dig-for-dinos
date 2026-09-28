local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Signal = require(External:WaitForChild("Signal"))
local Knit = require(External:WaitForChild("Knit"))

local ReplicationService = {
	Name = "ReplicationService",
	Client = {
		ReplicatorReplicated = Knit.CreateSignal(),
		ReplicatorUpdated = Knit.CreateSignal(),
		ReplicatorEvent = Knit.CreateSignal(),
		ReplicatorDereplicated = Knit.CreateSignal()
	},
	ReplicatorEventFiredFromClient = Signal.new()
}

function ReplicationService:KnitStart()
	self.Client.ReplicatorEvent:Connect(function(player, guid, eventName, ...)
		self.ReplicatorEventFiredFromClient:Fire(player, guid, eventName, ...)
	end)
end

function ReplicationService:Replicate(replicator, players)
	-- This function is called by Replicator class, do not call directly
	local replicationData = replicator:GetReplicationData()
	if not replicationData.Guid then
		error("Replicator replicationData doesn't have guid")
		return
	end

	if not replicationData.Type then
		error("Replicator replicationData doesn't have a Type")
		return
	end

	for _, player in pairs(players) do
		self.Client.ReplicatorReplicated:Fire(player, replicationData)
	end
end

function ReplicationService:UpdateReplicator(replicator, players)
	-- This function is called by Replicator class, do not call directly
	local replicationData = replicator:GetReplicationData()
	if not replicationData.Guid then
		error("Replicator replicationData doesn't have guid")
		return
	end

	for _, player in pairs(players) do
		self.Client.ReplicatorUpdated:Fire(player, replicationData)
	end
end

function ReplicationService:FireReplicatorEvent(replicator, players, eventName, ...)
	-- This function is called by Replicator class, do not call directly
	local replicationData = replicator:GetReplicationData()
	if not replicationData.Guid then
		error("Replicator replicationData doesn't have guid")
		return
	end

	for _, player in pairs(players) do
		self.Client.ReplicatorEvent:Fire(player, replicationData.Guid, eventName, ...)
	end
end

function ReplicationService:Dereplicate(replicator, players)
	-- This function is called by Replicator class, do not call directly
	local guid = replicator:GetGuid()
	if not guid then
		error("Replicator doesn't have guid")
		return
	end

	for _, player in pairs(players) do
		self.Client.ReplicatorDereplicated:Fire(player, guid)
	end
end

return ReplicationService