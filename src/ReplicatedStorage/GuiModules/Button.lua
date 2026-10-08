local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Player = game:GetService("Players").LocalPlayer
local Mouse = Player:GetMouse()

local External = ReplicatedStorage:WaitForChild("External")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local DefaultSound = Assets:WaitForChild("Sounds"):WaitForChild("ButtonClick")
local DefaultHoverSound = Assets:WaitForChild("Sounds"):WaitForChild("ButtonHover")
local Signal  = require(External:WaitForChild("Signal"))
local MouseOverModule = require(External:WaitForChild("MouseOverModule"))
local Trove = require(External:WaitForChild("Trove"))
local GuiObject = require(script.Parent:WaitForChild("Object"))
local Tooltip = require(script.Parent:WaitForChild("Tooltip"))
local Device = require(External:WaitForChild("Device"))

local Buttons = {}

local Button = {}
Button.__index = Button
setmetatable(Button, GuiObject)

function Button.new(button : GuiButton)
	if Button.GetButtonFromInstance(button) then
		return Button.GetButtonFromInstance(button)
	end

	local self = GuiObject.new(button)
	setmetatable(self, Button)

	self._ButtonBounceScale = 0.95
	self._ButtonScaleSize = 1.05
	self._Callback = nil
	self._MouseIsInside = false

	self._RotateWhenHover = false
	self._RotateAngle = -15
	self._RotateTween = nil

	self._CurrentSize = self._ObjectOriginalSize

	self._MakeNoiseWhenHover = true

	local icon = button:FindFirstChild("Icon")
	self:SetIcon(icon)
	self._MakeIconRotateLeftRightWhenHovered = false

	self._MakeIconScaleWhenHovered = false
	self._IconHoverScale = 1.125

	self._MakeShineWhenHovered = false
	self._ShineColor = Color3.fromRGB(255, 255, 255)
	self._ShineWidth = 0.5
	self._ShineTransparency = 0.75
	self._ShineTime = 1.5

	self._WiggleAngle = 5
	self._WiggleNum = 3
	self._WiggleTime = 0.25

	self.OnHoverChanged = Signal.new()

	self:SetHover(true)

	self:SetBounce(true)

	self:SetPlaybackSound(DefaultSound)
	self:SetHoverSound(DefaultHoverSound)

	-- Mouse and Keyboard are enabled in studio, even in mobile emulations (annoying)
	self._HoverTrove = Trove.new()

	self._LastDevice = nil
	local function inputTypeChanged(newDevice)
		if newDevice ~= self._LastDevice then
			self._LastDevice = newDevice

			self._HoverTrove:Clean()

			if (newDevice == "PC") or (newDevice == "Controller") then
				self:_InitializeHover()
			elseif newDevice == "Mobile" then
				self:_InitializeTouchHover()
			end
		end
	end

	self._InputChangedConnect = Device.DeviceUpdated:Connect(function(deviceType)
		inputTypeChanged(deviceType)
	end)
	inputTypeChanged(Device.GetUserDevice())

	self:_InitializePressDown()
	self:_InitializeActivated()

	self._AncestryChangedConnect = self._Object.AncestryChanged:Connect(function()
		if not self._Object.Parent then
			self:Destroy()
		end
	end)

	table.insert(Buttons, self)

	return self
end

function Button.GetButtonFromInstance(guiButton)
	for _, button in pairs(Buttons) do
		if button:GetObject() == guiButton then
			return button
		end
	end
end

function Button:_InitializeActivated()
	self._ActivatedConnect = self._Object.Activated:Connect(function()
		self:ButtonClicked(true)
	end)
end

function Button:ButtonClicked(clicked)
	if not self:GetButtonTrueVisibility() then
		return
	end

	if self._PlaybackSound then
		local newSound = self._PlaybackSound:Clone() :: Sound
		newSound.Parent = self._PlaybackSound.Parent
		newSound:Play()

		newSound.Ended:Connect(function()
			newSound:Destroy()
		end)

		newSound.Stopped:Connect(function()
			newSound:Destroy()
		end)
	end

	if self._Callback then
		self._Callback()
	end
end

function Button:ButtonHeldDown()
	if self._HeldDown then
		return
	end

	if not self._Bounce then
		return
	end

	if not self:GetButtonTrueVisibility() then
		return
	end

	self._SizeWhenHeldDown = self._Object.AbsoluteSize
	self._PositionWhenHeldDown = self._Object.AbsolutePosition

	local size = UDim2.new(
		self._ObjectOriginalSize.X.Scale * self._ButtonBounceScale,
		self._ObjectOriginalSize.X.Offset * self._ButtonBounceScale,
		self._ObjectOriginalSize.Y.Scale * self._ButtonBounceScale,
		self._ObjectOriginalSize.Y.Offset * self._ButtonBounceScale
	)

	local halfBounceTime = 0.1
	local tweenInfo = TweenInfo.new(halfBounceTime)

	local tween = TweenService:Create(self._Object, tweenInfo, {
		Size = size
	})

	tween:Play()

	self._CurrentSizeTween = tween

	self._HeldDown = true
end

function Button:ButtonReleased(isMouse)
	if not self._HeldDown then
		return
	end

	if not self._Bounce then
		return
	end

	if isMouse then
		local currentSize = self._Object.AbsoluteSize
		local currentPosition = self._Object.AbsolutePosition
		local x = Mouse.X
		local y = Mouse.Y
		if not ((x > currentPosition.X) and (x < currentPosition.X + currentSize.X)
		and
		(y > currentPosition.Y) and (y < currentPosition.Y + currentSize.Y)) then
			-- Mouse wasn't inside current button, but may still be inside what the button
			-- used to be (the button shrinks and grows when player clicks)
			-- This causes Activated to not call, but we still want it to call if the mouse
			-- was inside the old size
			local oldSize = self._SizeWhenHeldDown
			local oldPosition = self._PositionWhenHeldDown

			if (x > oldPosition.X) and (x < oldPosition.X + oldSize.X)
			and
			(y > oldPosition.Y) and (y < oldPosition.Y + oldSize.Y) then
				-- Button was inside where the button used to be when clicking on it
				self:ButtonClicked(true)
			end
		end
	end

	local halfBounceTime = 0.1
	local tweenInfo = TweenInfo.new(halfBounceTime)
	local tween = TweenService:Create(self._Object, tweenInfo, {
		Size = self._CurrentSize
	})

	tween:Play()

	self._CurrentSizeTween = tween

	self._HeldDown = false
end

function Button:_InitializePressDown()
	self._MouseButtonDownConnect = self._Object.MouseButton1Down:Connect(function()
		self:ButtonHeldDown()
	end)

	local inputObject
	self._PressDownInputBeganConnect = UserInputService.InputBegan:Connect(function(input)
		if inputObject then
			return
		end

		if not self._KeyCodes then
			return
		end

		if GuiService.SelectedObject then
			return
		end

		if table.find(self._KeyCodes, input.KeyCode) then
			self:ButtonHeldDown()
			inputObject = input
		end
	end)

	self._PressDownInputEndedConnect = UserInputService.InputEnded:Connect(function(input)
		if input == inputObject then
			self:ButtonReleased()
			inputObject = nil

			if table.find(self._KeyCodes, input.KeyCode) and self:GetButtonTrueVisibility() then
				self:ButtonClicked()
			end
		end
	end)

	self._InputEndedConnect = self._Object.InputEnded:Connect(function(input)
		if not ((input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch) or (input.KeyCode == Enum.KeyCode.ButtonA) or (input.KeyCode == Enum.KeyCode.Return)) then
			return
		end

		self:ButtonReleased(input.UserInputType == Enum.UserInputType.MouseButton1)
	end)
end

function Button:_InitializeTouchHover()
	local connection
	local function inputEnded()
		if not self._MouseIsInside then
			return
		end

		if connection then
			connection:Disconnect()
		end
		connection = nil

		if self._TooltipEnabled then
			self:_DestroyTooltip()
		end

		self._MouseIsInside = false

		self.OnHoverChanged:Fire(false)
	end

	self._HoverTrove:Add(self._Object.InputBegan:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.Touch) then
			self._MouseIsInside = true

			local trueVisibility = self:GetButtonTrueVisibility()
			if self._TooltipEnabled and trueVisibility then
				self:_CreateTooltip()
			end

			if trueVisibility then
				self.OnHoverChanged:Fire(true)
			end

			connection = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					inputEnded()
				end
			end)
		end
	end))

	self._HoverTrove:Add(self._Object.InputEnded:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.Touch) then
			inputEnded()
		end
	end))
end

function Button:_InitializeHover()
	local mouseEnter, mouseLeave
	local billboardGui = self._Object:FindFirstAncestorWhichIsA("BillboardGui")
	local surfaceGui = self._Object:FindFirstAncestorWhichIsA("SurfaceGui")

	if self._LastDevice ~= "Controller" then
		if billboardGui or surfaceGui then
			mouseEnter = self._Object.MouseEnter
			mouseLeave = self._Object.MouseLeave
		else
			mouseEnter, mouseLeave = MouseOverModule.MouseEnterLeaveEvent(self._Object)
		end
	else
		mouseEnter = self._Object.SelectionGained
		mouseLeave = self._Object.SelectionLost
	end

	self._HoverTrove:Add(mouseEnter:Connect(function()
		local trueVisibility = self:GetButtonTrueVisibility()

		self._MouseIsInside = true

		if self._TooltipEnabled and trueVisibility then
			self:_CreateTooltip()
		end

		local biggerTime = 0.1
		if self._MakeBiggerWhenHover and trueVisibility then
			local buttonScale = self._ButtonScaleSize
			local newOriginalSize = UDim2.new(
				self._CurrentSize.X.Scale * buttonScale,
				self._CurrentSize.X.Offset * buttonScale,
				self._CurrentSize.Y.Scale * buttonScale,
				self._CurrentSize.Y.Offset * buttonScale
			)

			local oldCurrentSize = self._CurrentSize

			self._CurrentSize = newOriginalSize

			if not self._HeldDown then
				self._Object.Size = oldCurrentSize

				local tweenInfo = TweenInfo.new(biggerTime)
				local tween = TweenService:Create(self._Object, tweenInfo, {
					Size = newOriginalSize
				})
				tween:Play()
				self._CurrentSizeTween = tween
			end
		end

		if self._MakeNoiseWhenHover and trueVisibility and (not self._HeldDown) then
			if self._HoverSound then
				local newSound = self._HoverSound:Clone()
				newSound.Parent = self._HoverSound.Parent

				newSound:Play()

				newSound.Ended:Connect(function()
					newSound:Destroy()
				end)

				newSound.Stopped:Connect(function()
					newSound:Destroy()
				end)
			end
		end

		if self._MakeIconRotateLeftRightWhenHovered and self._Icon and trueVisibility and (not self._HeldDown) then
			self._Icon:MakeRotateLeftRight()
		end

		if self._MakeIconScaleWhenHovered and self._Icon and trueVisibility and (not self._HeldDown) then
			self._Icon:TweenScale(self._IconHoverScale, TweenInfo.new(0.3))
		end

		if self._MakeWiggleWhenHovered and trueVisibility and (not self._HeldDown) then
			self:MakeWiggle(self._WiggleAngle, self._WiggleNum, self._WiggleTime)
		end

		if self._MakeShineWhenHovered and trueVisibility and (not self._HeldDown) then
			self:MakeShine(self._ShineWidth, self._ShineTransparency, self._ShineColor, self._ShineTime)
		end

		if trueVisibility and (not self._HeldDown) then
			self.OnHoverChanged:Fire(true)
		end

		if self._RotateWhenHover and trueVisibility and (not self._HeldDown) then
			self:_RotateButton(self._ObjectOriginalRotation + self._RotateAngle)
		end
	end))

	self._HoverTrove:Add(mouseLeave:Connect(function()
		self._MouseIsInside = false

		self.OnHoverChanged:Fire(false)

		if self._TooltipEnabled then
			self:_DestroyTooltip()
		end

		local biggerTime = 0.1
		if self._MakeBiggerWhenHover then
			self._CurrentSize = self._ObjectOriginalSize

			if not self._HeldDown then
				local tweenInfo = TweenInfo.new(biggerTime)
				local tween = TweenService:Create(self._Object, tweenInfo, {
					Size = self._CurrentSize
				})
				tween:Play()
				self._CurrentSizeTween = tween
			end
		end

		if self._RotateWhenHover then
			self:_RotateButton(self._ObjectOriginalRotation)
		end

		if self._MakeIconRotateLeftRightWhenHovered and self._Icon then
			self._Icon:StopRotateLeftRight(true)
		end

		if self._MakeIconScaleWhenHovered and self._Icon then
			self._Icon:TweenScale(1, TweenInfo.new(biggerTime))
		end
	end))

	self._HoverTrove:Add(function()
		MouseOverModule.Disconnect(self._Object)
	end)
end

function Button:GetButtonTrueVisibility()
	if not self._Object.Visible then
		return false
	end

	local parent = self._Object.Parent
	while parent do
		if parent:IsA("GuiObject") then
			if not parent.Visible then
				return false
			end
		elseif parent:IsA("LayerCollector") then
			if not parent.Enabled then
				return false
			end
		end

		parent = parent.Parent
	end

	return true
end

function Button:_RotateButton(angle)
	local tweenInfo = TweenInfo.new(0.1)
	local tween = TweenService:Create(self._Object, tweenInfo, {
		Rotation = angle
	})

	tween:Play()
end

function Button:SetTooltipGui(guiObject, parent, positionFunc)
	self._TooltipGui = guiObject
	self._TooltipParent = parent
	self._TooltipPosFunc = positionFunc
end

function Button:GetTooltip()
	if not self._Tooltip then
		return nil
	end

	return self._Tooltip:GetObject()
end

function Button:_CreateTooltip()
	self:_DestroyTooltip()

	if not self._TooltipGui then return end

	local newTooltip = self._TooltipGui:Clone()
	self._Tooltip = Tooltip.new(newTooltip, self._TooltipParent, self._TooltipPosFunc or function()
		if self._LastDevice == "Controller" then
			return self._Object.AbsolutePosition + GuiService:GetGuiInset()
		end

		return UserInputService:GetMouseLocation()
	end)
end

function Button:_DestroyTooltip()
	if self._Tooltip then
		self._Tooltip:Destroy()
	end
	self._Tooltip = nil
end

function Button:SetTooltipEnabled(enabled)
	if self._TooltipEnabled == enabled then
		return
	end

	self._TooltipEnabled = enabled

	local visibility = self:GetButtonTrueVisibility()

	if self._MouseIsInside and enabled and visibility then
		self:_CreateTooltip()
	elseif self._MouseIsInside and (not enabled) then
		self:_DestroyTooltip()
	end
end

function Button:SetHover(hover)
	self._MakeBiggerWhenHover = hover
end

function Button:IsHovered()
	return self._MouseIsInside
end

function Button:SetMakeNoiseWhenHover(bool)
	self._MakeNoiseWhenHover = bool
end

function Button:SetRotate(rotate)
	self._RotateWhenHover = rotate
end

function Button:SetRotateAngle(angle)
	self._RotateAngle = angle
end

function Button:SetButtonScaleSize(size)
	self._ButtonScaleSize = size
end

function Button:SetButtonBounceScaleSize(size)
	self._ButtonBounceScale = size
end

function Button:SetPlaybackSound(sound)
	if sound and not sound:IsA("Sound") then
		warn("Sound needs to be a Sound Object")
		return
	end

	self._PlaybackSound = sound
end

function Button:SetHoverSound(sound)
	if sound and not sound:IsA("Sound") then
		warn("Sound needs to be a Sound Object")
		return
	end

	self._HoverSound = sound
end

function Button:SetBounce(bounce)
	self._Bounce = bounce
end

function Button:SetCallback(callback)
	if type(callback) ~= "function" then
		warn("Callback is not a function!")
		return
	end

	self._Callback = callback
end

function Button:SetIcon(guiObject)
	if guiObject and not guiObject:IsA("GuiObject") then
		warn("Icon needs to be a GuiObject")
		return
	end

	if self._Icon then
		self._Icon:StopRotateLeftRight()
		self._Icon:TweenScale(1, TweenInfo.new(0.1))
	end

	if not guiObject then
		self._Icon = nil
		return
	end

	self._Icon = GuiObject.new(guiObject)
end

function Button:SetMakeIconRotateLeftRightWhenHovered(bool)
	self._MakeIconRotateLeftRightWhenHovered = bool
end

function Button:SetMakeIconScaleWhenHovered(bool)
	self._MakeIconScaleWhenHovered = bool
end

function Button:SetIconHoverScale(scale)
	self._IconHoverScale = scale
end

function Button:SetMakeShineWhenHovered(bool)
	self._MakeShineWhenHovered = bool
end

function Button:SetShineParams(width, transparency, color, time)
	self._ShineWidth = width or self._ShineWidth
	self._ShineTransparency = transparency or self._ShineTransparency
	self._ShineColor = color or self._ShineColor
	self._ShineTime = time or self._ShineTime
end

function Button:SetMakeWiggleWhenHovered(bool)
	self._MakeWiggleWhenHovered = bool
end

function Button:SetWiggleParams(angle, wiggles, timePerWiggle)
	self._WiggleAngle = angle
	self._WiggleNum = wiggles
	self._WiggleTime = timePerWiggle
end

function Button:SetButtonKeyCodes(keyCodes)
	self._KeyCodes = keyCodes
end

function Button:GetIconObject()
	return self._Icon
end

function Button:GetObject()
	return self._Object
end

function Button:Destroy()
	self:_DestroyTooltip()

	if self._AncestryChangedConnect then
		self._AncestryChangedConnect:Disconnect()
	end

	self.OnHoverChanged:Fire(false)
	self.OnHoverChanged:Destroy()

	if self._InputChangedConnect then
		self._InputChangedConnect:Disconnect()
	end

	if self._PressDownInputBeganConnect then
		self._PressDownInputBeganConnect:Disconnect()
	end

	if self._PressDownInputEndedConnect then
		self._PressDownInputEndedConnect:Disconnect()
	end

	if self._ActivatedConnect then
		self._ActivatedConnect:Disconnect()
	end

	if self._MouseButtonDownConnect then
		self._MouseButtonDownConnect:Disconnect()
	end

	if self._InputEndedConnect then
		self._InputEndedConnect:Disconnect()
	end

	local index = table.find(Buttons, self)
	if index then
		table.remove(Buttons, index)
	end

	if self._CurrentSizeTween then
		self._CurrentSizeTween:Cancel()
	end

	if self._Object.Parent then
		self._Object.Size = self._ObjectOriginalSize
	end

	self._HoverTrove:Clean()
end

return Button
