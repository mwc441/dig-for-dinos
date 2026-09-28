local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Tooltip = {}
Tooltip.__index = Tooltip

function Tooltip.new(guiObject: GuiObject, parent: Instance?, getPosition: (() -> Vector2)?)
	local self = {}
	setmetatable(self, Tooltip)

	self._Object = guiObject
	self._GetPosition = getPosition

	self._Object.Visible = true
	if parent then
		self._Object.Parent = parent
	end

	self._AncestryChangedConnect = self._Object.AncestryChanged:Connect(function()
		if self._Object and not self._Object.Parent then
			self:Destroy()
		end
	end)

	self:Position()

	self._MoveConnect = RunService.Heartbeat:Connect(function()
		if not self._Object then
			return
		end

		self:Position()
	end)

	return self
end

function Tooltip:GetObject()
	return self._Object
end

function Tooltip:GetPosition()
	if self._GetPosition then
		return self._GetPosition()
	end

	return UserInputService:GetMouseLocation()
end

function Tooltip:Position()
	if not self._Object then
		return
	end

	local position = self:GetPosition()
	self._Object.Position = UDim2.new(0, position.X, 0, position.Y)
end

function Tooltip:Destroy()
	if self._Destroyed then
		return
	end
	self._Destroyed = true

	if self._MoveConnect then
		self._MoveConnect:Disconnect()
	end
	self._MoveConnect = nil

	if self._AncestryChangedConnect then
		self._AncestryChangedConnect:Disconnect()
	end
	self._AncestryChangedConnect = nil

	if self._Object then
		self._Object:Destroy()
	end
	self._Object = nil
end

return Tooltip
