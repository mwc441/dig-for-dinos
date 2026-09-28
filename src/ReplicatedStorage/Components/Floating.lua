local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local External = ReplicatedStorage:WaitForChild("External")
local Component = require(External:WaitForChild("Component"))
local Trove = require(External:WaitForChild("Trove"))

local Floating = Component.new({
	Tag = "Floating",
	Ancestors = { Workspace },
})

function Floating:Construct()
	self.Instance = self.Instance :: PVInstance

	self._Trove = Trove.new()
end

function Floating:Start()
	local instance = self.Instance

	local speed = instance:GetAttribute("FloatSpeed") or 1.5
	local height = instance:GetAttribute("FloatHeight") or 0.5
	local animationMultiplier = instance:GetAttribute("FloatAnimMultiplier") or 2
	local offset = instance:GetAttribute("FloatOffset") or 0

	local startT = os.clock()
	local origin = instance:GetPivot() :: CFrame

	self._Trove:Add(RunService.Heartbeat:Connect(function()
		local t = os.clock()

		local elapsed = t - startT
		local offsetElapsed = elapsed + offset
		local floatPhase = offsetElapsed * speed

		local yOffset = math.sin(floatPhase) * height

		local rotX = math.sin(floatPhase * 0.8) * math.rad(6 * animationMultiplier)
		local rotY = math.sin(floatPhase * 0.6) * math.rad(5 * animationMultiplier)
		local rotZ = math.cos(floatPhase * 1.2) * math.rad(4 * animationMultiplier)

		local pos = origin.Position + Vector3.new(0, yOffset, 0)

		instance:PivotTo(CFrame.new(pos) * origin.Rotation * CFrame.Angles(rotX, rotY, rotZ))
	end))
end

function Floating:Stop()
	self._Trove:Clean()
end

return Floating