local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Knit = require(External:WaitForChild("Knit"))
local Signal = require(External:WaitForChild("Signal"))

local ServerDataController = {
	Name = "ServerDataController",
	_ServerDataService = nil,
	_ServerData = {},
	ServerDataUpdated = Signal.new()
}

function ServerDataController:KnitStart()
	self._ServerDataService = Knit.GetService("ServerDataService")

	self._ServerDataService.ServerData:Observe(function(serverData)
		self._ServerData = serverData
		self.ServerDataUpdated:Fire()
	end)
end

function ServerDataController:GetData(key)
	return self._ServerData[key]
end

return ServerDataController