local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local ClientAssets = Assets:WaitForChild("ClientAssets")
local IapSignGui = ClientAssets:WaitForChild("IapSignGui")
local External = ReplicatedStorage:WaitForChild("External")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local Component = require(External:WaitForChild("Component"))
local Signal = require(External:WaitForChild("Signal"))
local Trove = require(External:WaitForChild("Trove"))
local GuiButton = require(GuiModules:WaitForChild("Button"))

local IapSign = Component.new({
	Tag = "IapSign",
	Ancestors = { Workspace }
})

function IapSign:Construct()
	self.Instance = self.Instance :: BasePart

	self._Trove = Trove.new()
	self.Interacted = Signal.new()
	self._Trove:Add(self.Interacted)

	self:_SetupGui()

	local button = GuiButton.new(self.BuyButton)
	button:SetCallback(function()
		self.Interacted:Fire()
	end)

	local function updateEnabled()
		if not self.Gui then return end

		self.Gui.Enabled = self.Instance.Transparency < 1
	end

	self._Trove:Add(self.Instance:GetPropertyChangedSignal("Transparency"):Connect(function()
		updateEnabled()
	end))
	updateEnabled()
end

function IapSign:_SetupGui()
	local previousGui = self.Instance:FindFirstChild(IapSignGui.Name)
	if previousGui then previousGui:Destroy() end

	local gui = IapSignGui:Clone()
	gui.Adornee = self.Instance
	gui.Parent = Player:WaitForChild("PlayerGui")
	self._Trove:Add(gui)

	self.Gui = gui

	self.NameText = gui:WaitForChild("NameText")
	self.Icon = gui:WaitForChild("Icon")
	self.BuyButton = gui:WaitForChild("BuyButton")
	self.PriceText = self.BuyButton:WaitForChild("PriceText")
end

function IapSign:Stop()
	self._Trove:Clean()
end

return IapSign
