local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local External = ReplicatedStorage:WaitForChild("External")
local Component = require(External:WaitForChild("Component"))

local Hover = Component.new({
	Tag = "Hover",
	Ancestors = { Workspace }
})

function Hover:Construct()
	self:_Setup()
end

function Hover:_Setup()
	local hoverPVInstance = self.Instance

	local originalCframe = hoverPVInstance:GetPivot()
	local hoverDistance = hoverPVInstance:GetAttribute("HoverDistance") or 2
	local hoverTime = hoverPVInstance:GetAttribute("HoverTime") or 1

	local random = Random.new()
	local total = random:NextNumber()
	local direction = (math.random(0, 1) * 2) - 1
	self._Heartbeat = RunService.Heartbeat:Connect(function(dt)
		local camera = Workspace.CurrentCamera

		local distance = (camera.CFrame.Position - hoverPVInstance:GetPivot().Position).Magnitude
		if distance > 200 then
			return
		end

		total += math.clamp((dt / hoverTime), 0, 1)

		if total >= 1 then
			direction *= -1
			total = 0
		end

		local totalValue = TweenService:GetValue(total, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		local totalDistance = totalValue * (hoverDistance * 2)

		local yPos = (math.sign(-direction) * hoverDistance) + (math.sign(direction) * totalDistance)

		local newCFrame = originalCframe * CFrame.new(0, yPos, 0)

		hoverPVInstance:PivotTo(CFrame.new(newCFrame.Position) * hoverPVInstance:GetPivot().Rotation)
	end)
end

function Hover:Stop()
	if self._Heartbeat then
		self._Heartbeat:Disconnect()
	end
	self._Heartbeat = nil
end

return Hover