local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local External = ReplicatedStorage:WaitForChild("External")
local Trove = require(External:WaitForChild("Trove"))
local Signal = require(External:WaitForChild("Signal"))

local Slider = {}
Slider.__index = Slider

function Slider.new(progressBar)
	local self = {}
	setmetatable(self, Slider)

	self._Trove = Trove.new()

	self.SliderMoved = Signal.new()
	self._Trove:Add(self.SliderMoved)

	self.SliderFinishedMoving = Signal.new()
	self._Trove:Add(self.SliderFinishedMoving)

	self._ProgressBar = progressBar

	local bar = progressBar:FindFirstChild("Bar", true)
	if not bar then
		warn("No bar for slider")
		return
	end

	self._Bar = bar

	self._Slider = progressBar:FindFirstChild("Slider", true)

	self._Trove:Add(progressBar.AncestryChanged:Connect(function()
		if not progressBar.Parent then
			self:Destroy()
		end
	end))

	self:SetPercentage(0.5)

	self:_SetupInputs()

	return self
end

function Slider:_SetupInputs()
	local heartbeatConnection

	local function disconnect()
		self._Trove:Remove(heartbeatConnection)
		heartbeatConnection = nil
	end

	local thingToGrab = self._ProgressBar

	self._Trove:Add(thingToGrab.InputBegan:Connect(function(input)
		if not ((input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch)) then
			return
		end

		disconnect()

		heartbeatConnection = RunService.Heartbeat:Connect(function()
			local mousePos = UserInputService:GetMouseLocation()

			local absolutePosition = self._ProgressBar.AbsolutePosition
			local absoluteSize = self._ProgressBar.AbsoluteSize

			local difference = mousePos - absolutePosition

			local xScale = math.clamp(difference.X / absoluteSize.X, 0, 1)

			self:SetPercentage(xScale)

			self.SliderMoved:Fire()
		end)

		self._Trove:Add(heartbeatConnection)
	end))

	self._Trove:Add(thingToGrab.InputEnded:Connect(function(input)
		if not ((input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch)) then
			return
		end

		self.SliderFinishedMoving:Fire()

		disconnect()
	end))
end

function Slider:GetPercentage()
	return self._CurrentPercentage
end

function Slider:SetPercentage(scale)
	if self._Slider then
		local position = self._Slider.Position
		self._Slider.Position = UDim2.fromScale(scale, position.Y.Scale)
	end

	local oldSize = self._Bar.Size
	self._Bar.Size = UDim2.fromScale(scale, oldSize.Y.Scale)

	self._CurrentPercentage = scale
end

function Slider:Destroy()
	self._Trove:Clean()
end

return Slider