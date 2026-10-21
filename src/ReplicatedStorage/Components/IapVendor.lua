local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local ClientAssets = Assets:WaitForChild("ClientAssets")
local IapVendorGui = ClientAssets:WaitForChild("IapVendorGui")
local External = ReplicatedStorage:WaitForChild("External")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local Component = require(External:WaitForChild("Component"))
local Trove = require(External:WaitForChild("Trove"))
local Signal = require(External:WaitForChild("Signal"))

local IapVendor = Component.new({
	Tag = "IapVendor",
	Ancestors = { Workspace }
})

function IapVendor:Construct()
	self.Instance = self.Instance :: Model

	self._Trove = Trove.new()

	self.Interacted = Signal.new()
	self._Trove:Add(self.Interacted)

	self:_SetupGui()

	self.Prompt = UtilFunctions.CreateProximityPrompt(self.Instance.PrimaryPart)
	self._Trove:Add(self.Prompt)
	self._Trove:Connect(self.Prompt.Triggered, function()
		self.Interacted:Fire()
	end)
end

function IapVendor:_SetupGui()
	local primaryPart = self.Instance.PrimaryPart :: BasePart
	local gui = primaryPart:FindFirstChild("IapVendorGui") :: typeof(IapVendorGui)
	if not gui then
		gui = IapVendorGui:Clone()
		gui.Adornee = primaryPart
		gui.Parent = primaryPart
		self._Trove:Add(gui)
	end

	self.NameText = gui:WaitForChild("NameFrame"):WaitForChild("NameText")
	self.PriceText = gui:WaitForChild("PriceFrame"):WaitForChild("PriceText")
end

function IapVendor:Stop()
	self._Trove:Clean()
end

return IapVendor
