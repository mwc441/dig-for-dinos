local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local ClientAssets = Assets:WaitForChild("ClientAssets")
local BonePileGui = ClientAssets:WaitForChild("BonePileGui")
local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local DinosaurDef = require(ReplicatedConfigs:WaitForChild("DinosaurDef"))
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local RarityColorUtils = require(Utils:WaitForChild("RarityColorUtils"))
local Trove = require(External:WaitForChild("Trove"))
local Component = require(External:WaitForChild("Component"))
local BigNumbers = require(External:WaitForChild("BigNumbers"))

local BonePile = Component.new({
	Tag = "BonePile",
	Ancestors = { Workspace }
})

function BonePile:Construct()
	self.Instance = self.Instance :: Model

	self._Trove = Trove.new()

	self:_SetupGui()
end

function BonePile:_SetupGui()
	local dinoId = self.Instance:GetAttribute("DinosaurId")
	if not dinoId then return end

	local scale = self.Instance:GetAttribute("Scale")
	if not scale then return end

	local mutation = self.Instance:GetAttribute("Mutation")
	local zoneId = self.Instance:GetAttribute("ZoneId")

	local dinoInfo = DinosaurDef.GetDinosaurInfo(dinoId)
	if not dinoInfo then return end

	local newBonePileGui = BonePileGui:Clone()
	newBonePileGui.Adornee = self.Instance.PrimaryPart
	newBonePileGui.Parent = Player:WaitForChild("PlayerGui")

	newBonePileGui.RarityText.Text = dinoInfo.Rarity
	RarityColorUtils.SetColor(newBonePileGui.RarityText, dinoInfo.Rarity)
	newBonePileGui.SizeText.Text = string.format("Size: %0.1fx", scale)
	newBonePileGui.NameText.Text = dinoInfo.Name or ""
	RarityColorUtils.SetColor(newBonePileGui.NameText, dinoInfo.Rarity)

	newBonePileGui.MutationText.Visible = mutation ~= "Normal"
	newBonePileGui.MutationText.Text = mutation
	newBonePileGui.MutationText.UIGradient.Color = Constants.MutationGradients[mutation] or ColorSequence.new(Color3.fromRGB(255, 255, 255))

	local income = DinosaurDef.GetIncome(dinoId, scale, mutation, zoneId)
	newBonePileGui.IncomeFrame.AmountFrame.AmountText.Text = string.format("%s", BigNumbers.GetNumberDisplay(income))

	self._Trove:Add(newBonePileGui)
end

function BonePile:Stop()
	self._Trove:Clean()
end

return BonePile
