local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local BigNumbers = require(External:WaitForChild("BigNumbers"))

local DEFAULT_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local CountingText = {}
CountingText.__index = CountingText

function CountingText.new(textLabel: TextLabel, defaultValue: number?, formatString: string?)
	local self = {}
	setmetatable(self, CountingText)

	self._TextLabel = textLabel
	self._Value = defaultValue or 0
	self._LastDisplayedValue = self._Value
	self._Tween = nil
	self._NumberValue = nil
	self._TweenConnection = nil
	self._FormatString = formatString or "%s"

	self:Set(self._Value)

	self._AncestryChangedConnect = textLabel.AncestryChanged:Connect(function()
		if not textLabel.Parent then
			self:Destroy()
		end
	end)

	return self
end

function CountingText:Animate(newValue: number, tweenInfo: TweenInfo?)
	if self._Value == newValue then return end

	self:Stop()

	local tweenValue = Instance.new("NumberValue")
	tweenValue.Value = self._LastDisplayedValue
	self._NumberValue = tweenValue

	self._TweenConnection = tweenValue.Changed:Connect(function()
		local value = math.floor(tweenValue.Value)
		self._TextLabel.Text = string.format(self._FormatString, BigNumbers.GetNumberDisplay(value))
		self._LastDisplayedValue = value
	end)

	local tween = TweenService:Create(tweenValue, tweenInfo or DEFAULT_TWEEN_INFO, {
		Value = newValue,
	})

	self._Tween = tween

	tween.Completed:Once(function(playbackState)
		tweenValue:Destroy()
		self._NumberValue = nil

		if playbackState ~= Enum.PlaybackState.Completed then
			return
		end

		self:Set(newValue)
	end)

	tween:Play()
end

function CountingText:Set(newValue: number)
	self:Stop()

	self._Value = newValue
	self._TextLabel.Text = string.format(self._FormatString, BigNumbers.GetNumberDisplay(newValue))
	self._LastDisplayedValue = newValue
end

function CountingText:Stop()
	if self._Tween then
		self._Tween:Cancel()
		self._Tween = nil
	end

	if self._TweenConnection then
		self._TweenConnection:Disconnect()
		self._TweenConnection = nil
	end

	if self._NumberValue then
		self._NumberValue:Destroy()
		self._NumberValue = nil
	end
end

function CountingText:Destroy()
	self:Stop()

	if self._AncestryChangedConnect then
		self._AncestryChangedConnect:Disconnect()
		self._AncestryChangedConnect = nil
	end
end

return CountingText
