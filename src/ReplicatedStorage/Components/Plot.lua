local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local External = ReplicatedStorage:WaitForChild("External")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local ClientAssets = Assets:WaitForChild("ClientAssets")
local PlotOwnerGui = ClientAssets:WaitForChild("PlotOwnerGui")
local PlotLevelGui = ClientAssets:WaitForChild("PlotLevelGui")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local BigNumbers = require(External:WaitForChild("BigNumbers"))
local GuiButton = require(GuiModules:WaitForChild("Button"))
local PlotLevelDef = require(ReplicatedConfigs:WaitForChild("PlotLevelDef"))
local Transparency = require(Utils:WaitForChild("Transparency"))
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
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
	self._CapacityUsed = 0
	self._GamepassSignTransparencies = {}
	self._OwnedIaps = nil
	self.OwnerChanged = Signal.new()
	self._Trove:Add(self.OwnerChanged)

	self.LevelUpRequested = Signal.new()
	self._Trove:Add(self.LevelUpRequested)

	self._Trove:Connect(self.Instance:GetAttributeChangedSignal("Owner"), function()
		self:_UpdateOwner()
	end)

	self:_UpdateOwner()
end

function Plot:GetOwner() : Player?
	return self._Owner
end

function Plot:SetCapacityUsed(count : number)
	self._CapacityUsed = count
	self:_UpdateLevelGui()
end

function Plot:SetOwnedIaps(ownedIaps)
	self._OwnedIaps = ownedIaps
	self:_SetupGamepassSigns()
end

function Plot:_UpdateOwner()
	local ownerUserId = self.Instance:GetAttribute("Owner") or -1000
	local owner = Players:GetPlayerByUserId(ownerUserId)

	self:_CleanOwner()
	self._Owner = owner
	self._OwnerTrove = Trove.new()
	self._Trove:Add(self._OwnerTrove)

	if self._Owner then
		self:_BuildOwner()
	end

	self:_SetupPlotLeveling()
	self:_SetupGamepassSigns()

	self.OwnerChanged:Fire(self._Owner)
end

function Plot:_BuildOwner()
	if not self._Owner then return end

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

function Plot:_SetupGamepassSigns()
	for _, descendant in ipairs(self.Instance:QueryDescendants("#GamepassSign")) do
		local signPart = descendant.PrimaryPart
		local iapId = signPart and signPart.Name

		local transparency = self._GamepassSignTransparencies[descendant]
		if not transparency then
			transparency = Transparency.new(descendant)
			self._GamepassSignTransparencies[descendant] = transparency
		end

		if self._Owner == Player and self._OwnedIaps and not self._OwnedIaps[iapId] then
			transparency:Restore()
		else
			transparency:Hide()
		end
	end
end

function Plot:_SetupPlotLeveling()
	local levelSign : Model = self.Instance.LevelSign

	if not self._LevelSignTransparency then
		self._LevelSignTransparency = Transparency.new(levelSign)
	end

	if self._Owner == Player then
		self._LevelSignTransparency:Restore()

		self:_SetupLevelGui()

		self._OwnerTrove:Add(self.Instance:GetAttributeChangedSignal("Level"):Connect(function()
			self:_UpdateLevelGui()
		end))
		self:_UpdateLevelGui()
	else
		self._LevelSignTransparency:Hide()
	end
end

function Plot:_SetupLevelGui()
	if self._LevelGui then return end

	local levelSign : Model = self.Instance.LevelSign

	local newLevelGui = PlotLevelGui:Clone()
	newLevelGui.Adornee = levelSign.PrimaryPart
	newLevelGui.Parent = Player:WaitForChild("PlayerGui")

	local levelButton = GuiButton.new(newLevelGui.LevelButton)
	levelButton:SetCallback(function()
		self.LevelUpRequested:Fire()
	end)

	self._LevelGui = newLevelGui
	self._OwnerTrove:Add(self._LevelGui)
	self._OwnerTrove:Add(function()
		self._LevelGui = nil
	end)
end

function Plot:_UpdateLevelGui()
	if not self._LevelGui then return end

	local level = self.Instance:GetAttribute("Level") or 1
	local capacity = PlotLevelDef.GetCapacity(level)
	local cost = PlotLevelDef.GetUpgradeCost(level)

	self._LevelGui.AmountText.Text = string.format("(%d / %d)", self._CapacityUsed, capacity)
	if cost then
		self._LevelGui.LevelButton.AmountFrame.AmountText.Text = "$" .. BigNumbers.GetNumberDisplay(cost)
	else
		self._LevelGui.LevelButton.AmountFrame.AmountText.Text = "MAX"
	end
end

function Plot:ThrobLevelSign()
	if self._SignThrob then
		self._SignThrob()
		self._SignThrob = nil
	end

	self._SignThrob = UtilFunctions.ThrobModel(self.Instance.LevelSign, 1.15, 0.25)
end

function Plot:_CleanOwner()
	self._Trove:Remove(self._OwnerTrove)
	self._OwnerTrove = nil
end

function Plot:Stop()
	self._Trove:Clean()
end

return Plot
