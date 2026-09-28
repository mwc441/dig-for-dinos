local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Knit = require(External:WaitForChild("Knit"))
local Notification = require(script.Parent:WaitForChild("Notification"))

local NotificationController = {
	Name = "NotificationController",
	_NotificationZ = 0
}

function NotificationController:CreateNotification(args)
	if not args.NotificationType then
		return
	end

	self._NotificationZ += 1

	return Notification.new(args, self._NotificationZ)
end

return NotificationController