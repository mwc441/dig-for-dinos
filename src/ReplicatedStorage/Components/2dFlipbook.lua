local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local External = ReplicatedStorage:WaitForChild("External")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Flipbook2D = require(Utils:WaitForChild("2dFlipbook"))
local Component = require(External:WaitForChild("Component"))
local Trove = require(External:WaitForChild("Trove"))

local Flipbook = Component.new({
	Tag = "2dFlipbook",
	Ancestors = { Player:WaitForChild("PlayerGui"), Workspace }
})

local FLIPBOOK_ENABLED_ATTRIBUTE = "FlipbookEnabled"

function Flipbook:Construct()
	self.Instance = self.Instance :: ImageLabel

	self._Trove = Trove.new()

	local size = self.Instance:GetAttribute("Size") :: Vector2
	local rowSize = self.Instance:GetAttribute("Row") :: number
	local totalTiles = self.Instance:GetAttribute("Tiles") :: number
	local fps = self.Instance:GetAttribute("FPS") :: number
	local cooldown = self.Instance:GetAttribute("Cooldown") :: number?

	local flipbook = Flipbook2D.new(self.Instance, size, rowSize, totalTiles, fps)

	self._Flipbook = flipbook
	self._Cooldown = cooldown
	self._Enabled = false
	self._Trove:Add(self.Instance:GetAttributeChangedSignal(FLIPBOOK_ENABLED_ATTRIBUTE):Connect(function()
		self:SetEnabled(self.Instance:GetAttribute(FLIPBOOK_ENABLED_ATTRIBUTE) ~= false)
	end))

	self:SetEnabled(self.Instance:GetAttribute(FLIPBOOK_ENABLED_ATTRIBUTE) ~= false)

	self._Trove:Add(flipbook, "Destroy")
end

function Flipbook:SetEnabled(enabled)
	if self._Enabled == enabled then
		return
	end

	self._Enabled = enabled
	self.Instance:SetAttribute(FLIPBOOK_ENABLED_ATTRIBUTE, enabled)

	if enabled then
		if self._Cooldown then
			self._Flipbook:PlayOnCooldown(self._Cooldown)
		else
			self._Flipbook:Play()
		end
	else
		self._Flipbook:StopCooldown()
		self._Flipbook:Stop()
	end
end

function Flipbook:Toggle(enabled)
	if enabled == nil then
		enabled = not self._Enabled
	end

	self:SetEnabled(enabled)
end

function Flipbook:IsEnabled()
	return self._Enabled == true
end

function Flipbook:Stop()
	self._Trove:Clean()
end

return Flipbook
