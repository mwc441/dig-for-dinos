local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local External = ReplicatedStorage:WaitForChild("External")
local Component = require(External:WaitForChild("Component"))
local Trove = require(External:WaitForChild("Trove"))

local Animate = Component.new({
	Tag = "Animate",
	Ancestors = { Workspace }
})

function Animate:Construct()
	self._Trove = Trove.new()
end

function Animate:Start()
	local animation = self.Instance:FindFirstChildWhichIsA("Animation", true)
	local animator = self.Instance:FindFirstChildWhichIsA("Animator", true)

	if (not animation) or (not animator) then
		return
	end

	local animationTrack = animator:LoadAnimation(animation)
	animationTrack.Looped = true
	animationTrack:Play()

	self._Trove:Add(function()
		animationTrack:Stop()
		animationTrack:Destroy()
	end)
end

function Animate:Stop()
	self._Trove:Clean()
end

return Animate
