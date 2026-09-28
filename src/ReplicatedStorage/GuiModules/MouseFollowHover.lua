local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local External = ReplicatedStorage:WaitForChild("External")
local Trove = require(External:WaitForChild("Trove"))

local DEFAULT_MAX_SCALE = 0.04
local DEFAULT_FOLLOW_SPEED = 18
local DEFAULT_RETURN_TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local MouseFollowHover = {}
MouseFollowHover.__index = MouseFollowHover

local function getDefaultContents(button: GuiButton)
	local contents = button:FindFirstChild("Contents") or button:FindFirstChild("Content")
	if contents and contents:IsA("GuiObject") then
		return contents
	end

	for _, child in pairs(button:GetChildren()) do
		if child:IsA("GuiObject") then
			return child
		end
	end
end

function MouseFollowHover.new(button: GuiButton, contents: GuiObject?, maxScale: number?, followSpeed: number?)
	local self = {}
	setmetatable(self, MouseFollowHover)

	self._Button = button
	self._Contents = contents or getDefaultContents(button)
	self._MaxScale = maxScale or DEFAULT_MAX_SCALE
	self._FollowSpeed = followSpeed or DEFAULT_FOLLOW_SPEED
	self._ReturnTweenInfo = DEFAULT_RETURN_TWEEN_INFO
	self._OriginalPosition = self._Contents and self._Contents.Position
	self._CurrentScaleOffset = Vector2.zero
	self._Trove = Trove.new()

	if not self._Contents then
		warn("MouseFollowHover needs a contents GuiObject")
		return self
	end

	self._Trove:Add(button.MouseEnter:Connect(function()
		self:_StartFollowing()
	end))

	self._Trove:Add(button.MouseLeave:Connect(function()
		self:_ReturnHome()
	end))

	self._Trove:Add(button.AncestryChanged:Connect(function()
		if not button.Parent then
			self:Destroy()
		end
	end))

	self._Trove:Add(self._Contents.AncestryChanged:Connect(function()
		if not self._Contents.Parent then
			self:Destroy()
		end
	end))

	return self
end

function MouseFollowHover:_GetTargetScaleOffset()
	local mousePosition = UserInputService:GetMouseLocation()
	local buttonPosition = self._Button.AbsolutePosition
	local buttonSize = self._Button.AbsoluteSize
	local buttonCenter = buttonPosition + (buttonSize / 2)
	local halfSize = buttonSize / 2

	if halfSize.X <= 0 or halfSize.Y <= 0 then
		return Vector2.zero
	end

	local difference = mousePosition - buttonCenter
	local x = math.clamp(difference.X / halfSize.X, -1, 1)
	local y = math.clamp(difference.Y / halfSize.Y, -1, 1)

	return Vector2.new(x * self._MaxScale, y * self._MaxScale)
end

function MouseFollowHover:_GetPositionWithScaleOffset(scaleOffset: Vector2)
	local originalPosition = self._OriginalPosition

	return UDim2.new(
		originalPosition.X.Scale + scaleOffset.X,
		originalPosition.X.Offset,
		originalPosition.Y.Scale + scaleOffset.Y,
		originalPosition.Y.Offset
	)
end

function MouseFollowHover:_StartFollowing()
	if self._ReturnTween then
		self._ReturnTween:Cancel()
		self._ReturnTween = nil
	end

	if self._FollowConnection then
		return
	end

	self._FollowConnection = RunService.RenderStepped:Connect(function(dt)
		if not self._Contents or not self._Contents.Parent then
			self:Destroy()
			return
		end

		local targetOffset = self:_GetTargetScaleOffset()
		local alpha = 1 - math.exp(-self._FollowSpeed * dt)
		self._CurrentScaleOffset = self._CurrentScaleOffset:Lerp(targetOffset, alpha)
		self._Contents.Position = self:_GetPositionWithScaleOffset(self._CurrentScaleOffset)
	end)
end

function MouseFollowHover:_StopFollowing()
	if self._FollowConnection then
		self._FollowConnection:Disconnect()
		self._FollowConnection = nil
	end
end

function MouseFollowHover:_ReturnHome()
	self:_StopFollowing()

	if self._ReturnTween then
		self._ReturnTween:Cancel()
	end

	self._CurrentScaleOffset = Vector2.zero
	self._ReturnTween = TweenService:Create(self._Contents, self._ReturnTweenInfo, {
		Position = self._OriginalPosition,
	})

	self._ReturnTween:Play()
end

function MouseFollowHover:SetMaxScale(maxScale: number)
	self._MaxScale = maxScale
end

function MouseFollowHover:SetMaxOffset(maxOffset: number)
	self:SetMaxScale(maxOffset)
end

function MouseFollowHover:SetFollowSpeed(followSpeed: number)
	self._FollowSpeed = followSpeed
end

function MouseFollowHover:SetReturnTweenInfo(tweenInfo: TweenInfo)
	self._ReturnTweenInfo = tweenInfo
end

function MouseFollowHover:Destroy()
	if self._Destroyed then
		return
	end
	self._Destroyed = true

	self:_StopFollowing()

	if self._ReturnTween then
		self._ReturnTween:Cancel()
		self._ReturnTween = nil
	end

	if self._Contents and self._Contents.Parent then
		self._Contents.Position = self._OriginalPosition
	end

	self._Trove:Clean()
end

return MouseFollowHover
