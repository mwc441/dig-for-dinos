local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local External = ReplicatedStorage:WaitForChild("External")
local Component = require(External:WaitForChild("Component"))

local TeleportSpot = Component.new({
	Tag = "TeleportSpot",
	Ancestors = { Workspace }
})

function TeleportSpot.GetTeleportSpot(name: string)
	for _, teleportSpot in pairs(TeleportSpot:GetAll()) do
		if teleportSpot.Instance.Name == name then
			return teleportSpot
		end
	end
end

function TeleportSpot.TeleportPlayer(player: Player, teleportSpotName: string)
	local teleportSpot = TeleportSpot.GetTeleportSpot(teleportSpotName)
	if not teleportSpot then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local pivot = character:GetPivot()
	local boundingCFrame, boundingSize = character:GetBoundingBox()
	local bottomY = boundingCFrame.Position.Y - (boundingSize.Y / 2)
	local pivotToFeetOffset = pivot.Position.Y - bottomY

	character:PivotTo(teleportSpot.Instance:GetPivot() * CFrame.new(0, pivotToFeetOffset, 0))
end

return TeleportSpot
