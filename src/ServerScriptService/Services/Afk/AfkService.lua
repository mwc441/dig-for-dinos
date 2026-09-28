local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local SafeTeleport = require(External:WaitForChild("SafeTeleport"))
local Knit = require(External:WaitForChild("Knit"))

local AfkService = {
	Name = "AfkService",
	Client = {}
}

function AfkService.Client:Teleport(player, teleportData)
	if type(teleportData) ~= "table" then
		return
	end

	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions.ShouldReserveServer = false
	teleportOptions:SetTeleportData(teleportData)

	SafeTeleport(game.PlaceId, { player }, teleportOptions)
end

return AfkService