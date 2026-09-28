local Players = game:GetService("Players")

-- A replicator is something that exists only in memory on the server
-- but might have additional models/animations on the client!
-- An example of a Replicator would be an npc that is only memory on the server
-- but has models, animations, and pathfinding all on the client (to help reduce server lag)

-- To use this module, you create a child class of Replicator
-- and then change its Type, and extend the GetReplicationData function
-- For example, you may have a class called Npc, which will be a child class of
-- Replicator. The Npc might have its own unique data like a name (or etc)
-- which can be a part of its ReplicationData that is sent to the client
-- when its replicated. Then if you want to replicate the npc to the client,
-- just call Npc:ReplicateTo({players}) and it will automatically replicate
-- to the client using ReplicationService and ReplicationController

-- On the client end, you would hook up to signals that ReplicationController
-- has, Create, Update, and Delete, and then use those to create/upd/del your replicator (npc)
-- on the client!

-- The only down-side to this module, is that you need to get ReplicationService
-- and put that as an argument into the Replicator object, so if you create an Npc
-- Replicator, and a service called NpcService, you would have to get ReplicationService
-- in NpcService to create a npc replicator. Npc.new(replicationService, args)

local LastGuid = 0

local Replicator = {}
Replicator.__index = Replicator

function Replicator.new(replicationService)
	local self = {}
	setmetatable(self, Replicator)

	if not replicationService then
		error("Replicators need replicationService")
	end

	self._ReplicationService = replicationService

	self._PlayersReplicatedTo = {}

	self._Guid = LastGuid + 1

	LastGuid = self._Guid

	self._Type = "Replicator" -- Update this on child-classes

	self._PlayerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		self:DereplicateFor({ player })
	end)

	return self
end

function Replicator:GetGuid()
	return self._Guid
end

function Replicator:GetReplicationData()
	-- Implement this function further on child-classes
	return {
		Guid = self._Guid,
		Type = self._Type
	}
end

function Replicator:ReplicateTo(players)
	if self._Destroyed then
		return
	end

	for _, player in pairs(self._PlayersReplicatedTo) do
		local index = table.find(players, player)
		if index then
			table.remove(players, index)
		end
	end

	if #players <= 0 then
		return
	end

	self._ReplicationService:Replicate(self, players)

	for _, player in pairs(players) do
		table.insert(self._PlayersReplicatedTo, player)
	end
end

function Replicator:Update()
	if self._Destroyed then
		return
	end

	self._ReplicationService:UpdateReplicator(self, self._PlayersReplicatedTo)
end

function Replicator:FireEvent(eventName, ...)
	if self._Destroyed then
		return
	end

	self._ReplicationService:FireReplicatorEvent(self, self._PlayersReplicatedTo, eventName, ...)
end

function Replicator:DereplicateFor(players)
	if self._Destroyed then
		return
	end

	if #players <= 0 then
		return
	end

	self._ReplicationService:Dereplicate(self, players)

	for _, player in pairs(players) do
		local index = table.find(self._PlayersReplicatedTo, player)
		if index then
			table.remove(self._PlayersReplicatedTo, index)
		end
	end
end

function Replicator:Destroy()
	self._ReplicationService:Dereplicate(self, self._PlayersReplicatedTo)

	if self._PlayerRemovingConnection then
		self._PlayerRemovingConnection:Disconnect()
	end
	self._PlayerRemovingConnection = nil

	self._Destroyed = true

	self._PlayersReplicatedTo = nil
	self._ReplicationService = nil
	self._Guid = nil
end

return Replicator