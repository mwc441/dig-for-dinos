local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local External = ReplicatedStorage:WaitForChild("External")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local Component = require(External:WaitForChild("Component"))
local GuiObject = require(GuiModules:WaitForChild("Object"))

local Spin = Component.new({
	Tag = "Spin",
	Ancestors = { Workspace, Player:WaitForChild("PlayerGui") }
})

function Spin:Construct()
	self:_Setup()
end

function Spin:_Setup()
	local spinInstance = self.Instance

	local spinSpeed = spinInstance:GetAttribute("SpinSpeed") or 45

	if spinInstance:IsA("GuiObject") then
		self._GuiObject = GuiObject.new(spinInstance)
		self._GuiObject:SetSpinAngularSpeed(spinSpeed)
		self._GuiObject:StartSpin()
		return
	end

	self._Heartbeat = RunService.Heartbeat:Connect(function(dt)
		local totalAngleChange = dt * spinSpeed

		if spinInstance:IsA("Decal") then
			spinInstance.Rotation = (spinInstance.Rotation + totalAngleChange) % 360
		else
			spinInstance:PivotTo(spinInstance:GetPivot() * CFrame.Angles(0, math.rad(totalAngleChange), 0))
		end
	end)

	if spinInstance:IsA("BasePart") then
		spinInstance.AssemblyAngularVelocity = Vector3.new(0, math.rad(spinSpeed), 0)
	end
end

function Spin:Stop()
	if self._GuiObject then
		self._GuiObject:StopSpin()
		self._GuiObject = nil
	end

	if self._Heartbeat then
		self._Heartbeat:Disconnect()
	end
	self._Heartbeat = nil
end

return Spin
