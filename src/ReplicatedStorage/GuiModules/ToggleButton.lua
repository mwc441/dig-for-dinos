local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Signal = require(ReplicatedStorage:WaitForChild("External"):WaitForChild("Signal"))

local TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local ToggleButton = {}
ToggleButton.__index = ToggleButton

function ToggleButton.new(button, initialValue)
	local self = setmetatable({}, ToggleButton)

	self._Button = button
	self._Slider = button:WaitForChild("Slider")
	self._OnGradient = button:WaitForChild("OnGradient")
	self._OffGradient = button:WaitForChild("OffGradient")
	self._Value = nil
	self.Toggled = Signal.new()

	if initialValue == nil then
		initialValue = self._OnGradient.Enabled
	end
	self:SetValue(initialValue, false)

	self._AncestryConnection = button.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self:Destroy()
		end
	end)

	return self
end

function ToggleButton:Toggle()
	self:SetValue(not self._Value, true)
end

function ToggleButton:SetValue(value, animate)
	value = value == true
	if self._Value == value then return end
	local wasInitialized = self._Value ~= nil
	self._Value = value

	self._OnGradient.Enabled = value
	self._OffGradient.Enabled = not value

	if self._Tween then
		self._Tween:Cancel()
	end

	local x = value and 1 or 0
	local anchorPoint = self._Slider.AnchorPoint
	local position = self._Slider.Position
	local targetAnchorPoint = Vector2.new(x, anchorPoint.Y)
	local targetPosition = UDim2.new(x, 0, position.Y.Scale, position.Y.Offset)

	if animate == false then
		self._Slider.AnchorPoint = targetAnchorPoint
		self._Slider.Position = targetPosition
	else
		self._Tween = TweenService:Create(self._Slider, TWEEN_INFO, {
			AnchorPoint = targetAnchorPoint,
			Position = targetPosition
		})
		self._Tween:Play()
	end

	if wasInitialized then
		self.Toggled:Fire(value)
	end
end

function ToggleButton:GetValue()
	return self._Value
end

function ToggleButton:Destroy()
	if self._Destroyed then return end
	self._Destroyed = true

	if self._Tween then self._Tween:Cancel() end
	if self._AncestryConnection then self._AncestryConnection:Disconnect() end
	self.Toggled:Destroy()
end

return ToggleButton
