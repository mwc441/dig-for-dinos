local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local External = ReplicatedStorage:WaitForChild("External")
local Trove = require(External:WaitForChild("Trove"))
local Signal = require(External:WaitForChild("Signal"))

local MouseGrab = {}
MouseGrab.__index = MouseGrab

function MouseGrab.new(parentGui, guiObject, data)
	local self = {}
	setmetatable(self, MouseGrab)

	self._Parent = parentGui
	self._Data = data or {}
	self._Trove = Trove.new()
	self.Dropped = Signal.new()
	self.Moved = Signal.new()

	self:_SetupNewGuiObject(guiObject)

	self._Trove:Add(Mouse.Move:Connect(function()
		local mousePos = Vector2.new(Mouse.X, Mouse.Y)
		self:_Position(mousePos + self._MouseDifference)
	end))

	self._Trove:Add(UserInputService.InputEnded:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch) then
			self:Destroy()
		end

		if (input.UserInputType == Enum.UserInputType.Gamepad1) and (input.KeyCode == Enum.KeyCode.ButtonA) then
			self:Destroy()
		end
	end))

	return self
end

function MouseGrab:GetData()
	return self._Data
end

function MouseGrab:_SetupNewGuiObject(guiObject)
	local newGuiObject = guiObject:Clone()
	newGuiObject.Size = UDim2.new(0, guiObject.AbsoluteSize.X, 0, guiObject.AbsoluteSize.Y)
	newGuiObject.ZIndex = math.pow(2, 31) - 1
	newGuiObject.Parent = self._Parent

	self._GuiObject = newGuiObject

	self._Trove:Add(newGuiObject)

	self:_Position(guiObject.AbsolutePosition)

	local mousePos = Vector2.new(Mouse.X, Mouse.Y)
	self._MouseDifference = self._GuiObject.AbsolutePosition - mousePos
end

function MouseGrab:_Position(position)
	if not self._GuiObject then
		return
	end

	local guiInset = GuiService:GetGuiInset()

	local anchorPoint = self._GuiObject.AnchorPoint
	local size = self._GuiObject.AbsoluteSize
	local y = position.Y + guiInset.Y + (anchorPoint.Y * size.Y)
	local x = position.X + (anchorPoint.X * size.X)

	self._GuiObject.Position = UDim2.new(0, x, 0, y)

	self.Moved:Fire(Mouse.X, Mouse.Y)
end

function MouseGrab:Destroy()
	self.Dropped:Fire()
	self.Dropped:Destroy()

	self.Moved:Destroy()

	self._Trove:Clean()
end

return MouseGrab