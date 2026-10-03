local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local External = ReplicatedStorage:WaitForChild("External")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local ClientAssets = Assets:WaitForChild("ClientAssets")
local PlotOwnerGui = ClientAssets:WaitForChild("PlotOwnerGui")
local Component = require(External:WaitForChild("Component"))
local Signal = require(External:WaitForChild("Signal"))
local Trove = require(External:WaitForChild("Trove"))

local Plot = Component.new({
	Tag = "Plot",
	Ancestors = { Workspace }
})

function Plot:Construct()
	self.Instance = self.Instance :: Model

	self._Trove = Trove.new()
	self._OwnerTrove = nil
	self._Owner = nil :: Player?
	self.OwnerChanged = Signal.new()
	self._Trove:Add(self.OwnerChanged)

	self._Trove:Connect(self.Instance:GetAttributeChangedSignal("Owner"), function()
		self:_UpdateOwner()
	end)

	self:_UpdateOwner()
end

function Plot:GetOwner() : Player?
	return self._Owner
end

function Plot:_UpdateOwner()
	local ownerUserId = self.Instance:GetAttribute("Owner") or -1000
	local owner = Players:GetPlayerByUserId(ownerUserId)
	if self._Owner == owner then return end

	self:_CleanOwner()
	self._Owner = owner

	if self._Owner then
		self:_BuildOwner()
	end

	self.OwnerChanged:Fire(self._Owner)
end

function Plot:_BuildOwner()
	if not self._Owner then return end

	self._OwnerTrove = Trove.new()
	self._Trove:Add(self._OwnerTrove)

	self:_SetupPlotOwnerGui()
end

function Plot:_SetupPlotOwnerGui()
	local newPlotOwnerGui = PlotOwnerGui:Clone()
	newPlotOwnerGui.Adornee = self.Instance.PrimaryPart
	newPlotOwnerGui.Parent = Player:WaitForChild("PlayerGui")

	newPlotOwnerGui.Icon.Image = ""
	newPlotOwnerGui.NameText.Text = self._Owner.DisplayName

	self._PlotOwnerGui = newPlotOwnerGui

	self._OwnerTrove:Add(task.spawn(function()
		newPlotOwnerGui.Icon.Image = Players:GetUserThumbnailAsync(self._Owner.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180)
	end))
	self._OwnerTrove:Add(newPlotOwnerGui)
end

function Plot:_CleanOwner()
	self._Trove:Remove(self._OwnerTrove)
	self._OwnerTrove = nil
end

function Plot:Stop()
	self._Trove:Clean()
end

return Plot
