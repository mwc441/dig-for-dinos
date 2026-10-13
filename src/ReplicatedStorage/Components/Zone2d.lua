local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local External = ReplicatedStorage:WaitForChild("External")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Component = require(External:WaitForChild("Component"))
local Signal = require(External:WaitForChild("Signal"))
local Trove = require(External:WaitForChild("Trove"))
local PartUtil = require(Utils:WaitForChild("Part"))

local Zone2d = Component.new({
	Tag = "Zone2d",
	Ancestors = { Workspace }
})

Zone2d.EnteredZone = Signal.new()
Zone2d.ExitedZone = Signal.new()

function Zone2d:Construct()
	self._Trove = Trove.new()
	self._Part = PartUtil.new(self.Instance)
	self._IsLocalPlayerInside = false

	self.Entered = Signal.new()
	self._Trove:Add(self.Entered)

	self.Exited = Signal.new()
	self._Trove:Add(self.Exited)
end

function Zone2d:Start()
	self._Trove:Add(RunService.Heartbeat:Connect(function()
		local isInside = self._Part:PlayerIsInsidePartArea(Player, math.huge)

		if isInside and not self._IsLocalPlayerInside then
			self._IsLocalPlayerInside = true
			self.Entered:Fire()
			Zone2d.EnteredZone:Fire(self)
		elseif self._IsLocalPlayerInside and not isInside then
			self._IsLocalPlayerInside = false
			self.Exited:Fire()
			Zone2d.ExitedZone:Fire(self)
		end
	end))
end

function Zone2d:Stop()
	self._Trove:Clean()
end

function Zone2d:IsLocalPlayerInside()
	return self._IsLocalPlayerInside
end

function Zone2d.GetZone2d(name: string)
	for _, zone2d in pairs(Zone2d:GetAll()) do
		if zone2d.Instance.Name == name then
			return zone2d
		end
	end
end

function Zone2d.GetByName(name: string)
	return Zone2d.GetZone2d(name)
end

function Zone2d.IsPlayerInside(name: string)
	local zone = Zone2d.GetZone2d(name)
	if not zone then return false end

	return zone:IsLocalPlayerInside()
end

function Zone2d.ConnectToZone(name: string, callback)
	local enterConnect = Zone2d.EnteredZone:Connect(function(zone)
		if zone.Instance.Name == name then
			callback(true)
		end
	end)

	local exitConnect = Zone2d.ExitedZone:Connect(function(zone)
		if zone.Instance.Name == name then
			callback(false)
		end
	end)

	return {
		Disconnect = function()
			enterConnect:Disconnect()
			exitConnect:Disconnect()
		end
	}
end

return Zone2d
