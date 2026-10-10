local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local External = ReplicatedStorage:WaitForChild("External")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local Component = require(External:WaitForChild("Component"))
local Trove = require(External:WaitForChild("Trove"))
local Signal = require(External:WaitForChild("Signal"))

local SellStore = Component.new({
	Tag = "SellStore",
	Ancestors = { Workspace }
})

function SellStore:Construct()
	self.Instance = self.Instance :: BasePart

	self._Trove = Trove.new()

	self.Interacted = Signal.new()
	self._Trove:Add(self.Interacted)

	self:_Setup()
end

function SellStore:_Setup()
	local newProximityPrompt = UtilFunctions.CreateProximityPrompt(self.Instance, {
		ObjectText = "Open"
	})
	self._Trove:Add(newProximityPrompt)

	newProximityPrompt.Triggered:Connect(function()
		self.Interacted:Fire()
	end)
end

function SellStore:Stop()
	self._Trove:Clean()
end

return SellStore