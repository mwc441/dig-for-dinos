local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local Player = Players.LocalPlayer

local External = ReplicatedStorage:WaitForChild("External")
local Knit = require(External:WaitForChild("Knit"))

local AfkController = {
	Name = "AfkController",
	_AfkService = nil,
	TeleportData = {}
}

function AfkController:KnitStart()
	self._AfkService = Knit.GetService("AfkService")

	local afkBusy = false
	Player.Idled:Connect(function(idleTime)
		if afkBusy then
			return
		end

		if idleTime >= (15 * 60) then
			afkBusy = true

			self._AfkService:Teleport(self.TeleportData)
		end
	end)
end

return AfkController