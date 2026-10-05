local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local External = ReplicatedStorage:WaitForChild("External")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local Component = require(External:WaitForChild("Component"))
local Trove = require(External:WaitForChild("Trove"))
local Signal = require(External:WaitForChild("Signal"))

local GroupReward = Component.new({
	Tag = "GroupReward",
	Ancestors = { Workspace }
})

function GroupReward:Construct()
	self.Instance = self.Instance :: BasePart

	self._Trove = Trove.new()

	self.Interacted = Signal.new()
	self._Trove:Add(self.Interacted)

	self:_Setup()
end

function GroupReward:_Setup()
	local newProximityPrompt = UtilFunctions.CreateProximityPrompt(self.Instance)
	self._Trove:Add(newProximityPrompt)

	newProximityPrompt.Triggered:Connect(function()
		self.Interacted:Fire()
	end)
end

function GroupReward:Stop()
	self._Trove:Clean()
end

return GroupReward