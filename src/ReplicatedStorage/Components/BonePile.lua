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
local RarityTextUtils = require(Utils:WaitForChild("RarityTextUtils"))
local Trove = require(External:WaitForChild("Trove"))
local Component = require(External:WaitForChild("Component"))

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

	local dinoInfo = DinosaurDef.GetDinosaurInfo(dinoId)
	if not dinoInfo then return end

	local newBonePileGui = BonePileGui:Clone()
	newBonePileGui.Adornee = self.Instance.PrimaryPart
	newBonePileGui.Parent = Player:WaitForChild("PlayerGui")

	newBonePileGui.RarityText.Text = dinoInfo.Rarity
	RarityTextUtils.SetColor(newBonePileGui.RarityText, dinoInfo.Rarity)
	newBonePileGui.SizeText.Text = string.format("Size: %0.1fx", scale)
	newBonePileGui.NameText.Text = dinoInfo.Name or ""
	RarityTextUtils.SetColor(newBonePileGui.NameText, dinoInfo.Rarity)

	self._Trove:Add(newBonePileGui)
end

function BonePile:Stop()
	self._Trove:Clean()
end

return BonePile
