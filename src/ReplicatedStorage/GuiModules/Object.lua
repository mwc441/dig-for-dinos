local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local External = ReplicatedStorage:WaitForChild("External")
local UIParticle = require(External:WaitForChild("2dParticles"))

local SPARKLE_IMAGE_ID = "rbxassetid://126956770882149"

local GuiObject = {}
GuiObject.__index = GuiObject

function GuiObject.new(instance)
	local self = {}
	setmetatable(self, GuiObject)

	self._Object = instance

	if (not self._Object:IsA("UIStroke")) and (not self._Object:IsA("UIGradient")) then
		self._ObjectOriginalSize = instance.Size
		self._ObjectOriginalPosition = instance.Position
		self._ObjectOriginalRotation = instance.Rotation
	end

	self._HoverBigScale = 1.1
	self._HoverSmallScale = 0.9
	self._HoverHalfTime = 0.5
	self._HoverTween = nil
	self._HoverTask = nil

	self._FloatScale = 0.05
	self._FloatHalfTime = 1
	self._FloatTween = nil
	self._FloatTask = nil
	self._FloatLeftRightTween = nil
	self._FloatLeftRightTask = nil

	self._RotateLeftRightTime = 0.5
	self._RotateLeftRightTask = nil
	self._RotateLeftRightRot = 10
	self._RotateLeftRightTween = nil

	self._SparkleEmitter = nil

	self._SpinConnection = nil
	self._SpinAngularSpeed = 80 -- Degrees per second

	self._TweenRainbowConnection = nil

	local connection
	connection = self._Object.AncestryChanged:Connect(function()
		if not self._Object.Parent then
			self:StopSparkle()
			self:StopHoverBackAndForth()
			self:StopSpin()
			self:StopRotateLeftRight()
			self:StopTweenThroughRainbow()
			self:StopRainbow()
			self:StopFloatUpAndDown()
			self:StopFloatLeftAndRight()
			self:StopShine()
			self:StopTextShine()
			self:StopRepeatMakeShine()
			self:StopRepeatGrowAndFade()
			self:StopRepeatGrowFrameOutlineAndFade()
			self:StopRotateRainbow()
			self:StopShake()
			self:StopWiggle()
			self:StopPulse()
			connection:Disconnect()
		end
	end)

	return self
end

function GuiObject:GetObject()
	return self._Object
end

function GuiObject:SetHoverHalfTime(time)
	self._HoverHalfTime = time
end

function GuiObject:SetFloatHalfTime(time)
	self._FloatHalfTime = time
end

function GuiObject:SetFloatScale(scale)
	self._FloatScale = scale
end

function GuiObject:SetSpinAngularSpeed(speed)
	self._SpinAngularSpeed = speed
end

function GuiObject:SetRotateLeftRightAngle(deg)
	self._RotateLeftRightRot = deg
end

function GuiObject:SetRotateLeftRightTime(time)
	self._RotateLeftRightTime = time
end

function GuiObject:SetHoverBackForth(smallScale, bigScale, halfTime)
	self._HoverSmallScale = smallScale or self._HoverSmallScale
	self._HoverBigScale = bigScale or self._HoverBigScale
	self._HoverHalfTime = halfTime or self._HoverHalfTime
end

function GuiObject:MakeHoverBackAndForth()
	self:StopHoverBackAndForth()

	local tweenInfo = TweenInfo.new(self._HoverHalfTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	self._HoverTask = task.spawn(function()
		while true do
			local bigSize = UDim2.new(
				self._ObjectOriginalSize.X.Scale * self._HoverBigScale,
				self._ObjectOriginalSize.X.Offset * self._HoverBigScale,
				self._ObjectOriginalSize.Y.Scale * self._HoverBigScale,
				self._ObjectOriginalSize.Y.Offset * self._HoverBigScale
			)
			local bigTween = TweenService:Create(self._Object, tweenInfo, {
				Size = bigSize
			})

			bigTween:Play()
			self._HoverTween = bigTween
			task.wait(self._HoverHalfTime)

			local smallSize = UDim2.new(
				self._ObjectOriginalSize.X.Scale * self._HoverSmallScale,
				self._ObjectOriginalSize.X.Offset * self._HoverSmallScale,
				self._ObjectOriginalSize.Y.Scale * self._HoverSmallScale,
				self._ObjectOriginalSize.Y.Offset * self._HoverSmallScale
			)
			local smallTween = TweenService:Create(self._Object, tweenInfo, {
				Size = smallSize
			})

			smallTween:Play()
			self._HoverTween = smallTween
			task.wait(self._HoverHalfTime)
		end
	end)
end

function GuiObject:StopHoverBackAndForth()
	if self._HoverTween then
		self._HoverTween:Cancel()
	end
	self._HoverTween = nil

	if self._HoverTask then
		task.cancel(self._HoverTask)
	end
	self._HoverTask = nil

	self._Object.Size = self._ObjectOriginalSize
end

function GuiObject:MakeFloatUpAndDown()
	local tweenInfo = TweenInfo.new(self._FloatHalfTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	self._FloatTask = task.spawn(function()
		while true do
			local upPos = UDim2.new(
				self._ObjectOriginalPosition.X.Scale,
				self._ObjectOriginalPosition.X.Offset,
				self._ObjectOriginalPosition.Y.Scale - self._FloatScale,
				self._ObjectOriginalPosition.Y.Offset
			)
			local tween = TweenService:Create(self._Object, tweenInfo, {
				Position = upPos
			})

			tween:Play()

			self._FloatTween = tween
			task.wait(self._FloatHalfTime)

			local downPos = UDim2.new(
				self._ObjectOriginalPosition.X.Scale,
				self._ObjectOriginalPosition.X.Offset,
				self._ObjectOriginalPosition.Y.Scale + self._FloatScale,
				self._ObjectOriginalPosition.Y.Offset
			)
			tween = TweenService:Create(self._Object, tweenInfo, {
				Position = downPos
			})

			tween:Play()
			self._FloatTween = tween

			task.wait(self._FloatHalfTime)
		end
	end)
end

function GuiObject:StopFloatUpAndDown()
	if self._FloatTween then
		self._FloatTween:Cancel()
	end
	self._FloatTween = nil

	if self._FloatTask then
		task.cancel(self._FloatTask)
	end
	self._FloatTask = nil

	self._Object.Position = self._ObjectOriginalPosition
end

function GuiObject:MakeFloatLeftAndRight()
	self:StopFloatLeftAndRight()

	local tweenInfo = TweenInfo.new(self._FloatHalfTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	self._FloatLeftRightTask = task.spawn(function()
		while true do
			local leftPos = UDim2.new(
				self._ObjectOriginalPosition.X.Scale - self._FloatScale,
				self._ObjectOriginalPosition.X.Offset,
				self._ObjectOriginalPosition.Y.Scale,
				self._ObjectOriginalPosition.Y.Offset
			)
			local tween = TweenService:Create(self._Object, tweenInfo, {
				Position = leftPos
			})

			tween:Play()

			self._FloatLeftRightTween = tween
			task.wait(self._FloatHalfTime)

			local rightPos = UDim2.new(
				self._ObjectOriginalPosition.X.Scale + self._FloatScale,
				self._ObjectOriginalPosition.X.Offset,
				self._ObjectOriginalPosition.Y.Scale,
				self._ObjectOriginalPosition.Y.Offset
			)
			tween = TweenService:Create(self._Object, tweenInfo, {
				Position = rightPos
			})

			tween:Play()
			self._FloatLeftRightTween = tween

			task.wait(self._FloatHalfTime)
		end
	end)
end

function GuiObject:StopFloatLeftAndRight()
	if self._FloatLeftRightTween then
		self._FloatLeftRightTween:Cancel()
	end
	self._FloatLeftRightTween = nil

	if self._FloatLeftRightTask then
		task.cancel(self._FloatLeftRightTask)
	end
	self._FloatLeftRightTask = nil

	self._Object.Position = self._ObjectOriginalPosition
end

function GuiObject:MakeRotateLeftRight()
	if self._RotateLeftRightTask then
		return
	end

	local rotates = 0
	self._RotateLeftRightTask = task.spawn(function()
		local direction = math.random(0, 1) * 2 - 1
		while true do
			rotates += 1

			local totalTime = (rotates == 1) and (self._RotateLeftRightTime / 2) or self._RotateLeftRightTime

			local tweenInfo = TweenInfo.new(totalTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			local tween = TweenService:Create(self._Object, tweenInfo, {
				Rotation = self._ObjectOriginalRotation + self._RotateLeftRightRot * direction
			})

			tween:Play()
			self._RotateLeftRightTween = tween

			task.wait(totalTime)

			direction *= -1
		end
	end)
end

function GuiObject:StopRotateLeftRight(toTween)
	if self._RotateLeftRightTween then
		self._RotateLeftRightTween:Cancel()
	end
	self._RotateLeftRightTween = nil

	if self._RotateLeftRightTask then
		task.cancel(self._RotateLeftRightTask)
	end
	self._RotateLeftRightTask = nil

	if not toTween then
		self._Object.Rotation = self._ObjectOriginalRotation
	else
		local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Linear)
		local tween = TweenService:Create(self._Object, tweenInfo, {
			Rotation = self._ObjectOriginalRotation
		})

		tween:Play()
	end
end

function GuiObject:MakeSparkle(rate, size)
	local guiParticleEmitter = UIParticle.newEmitter(self._Object)

	local newSparkleImage = Instance.new("ImageLabel")
	newSparkleImage.Image = SPARKLE_IMAGE_ID
	newSparkleImage.Size = size or UDim2.fromScale(0.3, 0.3)
	newSparkleImage.ScaleType = Enum.ScaleType.Fit
	newSparkleImage.AnchorPoint = Vector2.new(0.5, 0.5)
	newSparkleImage.BackgroundTransparency = 1

	guiParticleEmitter:SetEmitterParticle(newSparkleImage)
	guiParticleEmitter:SetEmitterRate(rate or 1.5)
	guiParticleEmitter:SetEmissionShape("area")
	guiParticleEmitter:SetSpeed(0)
	guiParticleEmitter:SetRotation(0, 360)
	guiParticleEmitter:SetRotationSpeed(0.2, 0.5)
	guiParticleEmitter:SetLifetime(1, 1.5)
	guiParticleEmitter:SetScale(NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.25, 1),
		NumberSequenceKeypoint.new(0.75, 1),
		NumberSequenceKeypoint.new(1, 0)
	}))

	self._SparkleEmitter = guiParticleEmitter
end

function GuiObject:StopSparkle()
	if self._SparkleEmitter then
		self._SparkleEmitter:Destroy()
	end
	self._SparkleEmitter = nil
end

function GuiObject:MakeTweenThroughRainbow(isTextRainbow)
	local totalTime = 5
	local maxHsvHue = 359
	local total = math.random() * totalTime
	self._TweenRainbowConnection = RunService.RenderStepped:Connect(function(dt)
		total += dt

		if total > totalTime then
			total = math.max(0, total - totalTime)
		end

		local ratio = maxHsvHue * (total / totalTime)

		local hue = math.round(maxHsvHue - ratio) / maxHsvHue
		local saturation = 145 / 255
		local value = 1

		local color = Color3.fromHSV(hue, saturation, value)

		if self._Object:IsA("UIStroke") then
			self._Object.Color = color
		elseif self._Object:IsA("TextLabel") and isTextRainbow then
			self._Object.TextColor3 = color
		elseif self._Object:IsA("ImageLabel") then
			self._Object.ImageColor3 = color
		else
			self._Object.BackgroundColor3 = color
		end
	end)
end

function GuiObject:StopTweenThroughRainbow()
	if self._TweenRainbowConnection then
		self._TweenRainbowConnection:Disconnect()
	end
	self._TweenRainbowConnection = nil
end

function GuiObject:MakeRainbow(saturation: number?, value: number?)
	if self._Rainbowing then
		return
	end

	self._Rainbowing = true

	local gradient = self._Object:FindFirstChildWhichIsA("UIGradient")
	if gradient then
		gradient:Destroy()
	end

	if not self._RainbowGradient then
		local uiGradient =  Instance.new("UIGradient")
		uiGradient.Parent = self._Object

		self._RainbowGradient = uiGradient
	end

	local colors = {}
	local totalKeypoints = 10
	for i = 1, totalKeypoints do
		local place = (i - 1) / (totalKeypoints - 1)

		local color = Color3.fromHSV(place, saturation or 1, value or 1)

		table.insert(colors, ColorSequenceKeypoint.new(place, color))
	end

	local colorSequence = ColorSequence.new(colors)

	self._RainbowGradient.Color = colorSequence

	local totalTime = 3
	local maxHsvHue = 359
	self._RainbowConnection = RunService.Heartbeat:Connect(function(dt)
		local colors = {}
		for _, keypoint in pairs(self._RainbowGradient.Color.Keypoints) do
			local hue, s, v = keypoint.Value:ToHSV()

			local ratio = dt / totalTime
			local hsvAdd = maxHsvHue * ratio

			local totalHue = ((hue * maxHsvHue) + hsvAdd)
			if totalHue >= maxHsvHue then
				totalHue -= maxHsvHue
			end

			local newHue = math.clamp(totalHue / maxHsvHue, 0, 1)

			local newColor = Color3.fromHSV(newHue, s, v)
			table.insert(colors, ColorSequenceKeypoint.new(keypoint.Time, newColor))
		end

		local newColorSequence = ColorSequence.new(colors)
		self._RainbowGradient.Color = newColorSequence
	end)
end

function GuiObject:StopRainbow()
	if self._RainbowGradient then
		self._RainbowGradient:Destroy()
	end
	self._RainbowGradient = nil

	if self._RainbowConnection then
		self._RainbowConnection:Disconnect()
	end
	self._RainbowConnection = nil

	self._Rainbowing = false
end

function GuiObject:MakeRotateRainbow()
	local gradient = self._Object:FindFirstChildWhichIsA("UIGradient")
	if gradient then
		gradient:Destroy()
	end

	if not self._RainbowGradient then
		local uiGradient =  Instance.new("UIGradient")
		uiGradient.Parent = self._Object

		self._RainbowGradient = uiGradient
	end

	local colors = {}
	local totalKeypoints = 10
	for i = 1, totalKeypoints do
		local place = (i - 1) / (totalKeypoints - 1)

		local color = Color3.fromHSV(place, 1, 1)

		table.insert(colors, ColorSequenceKeypoint.new(place, color))
	end

	local colorSequence = ColorSequence.new(colors)
	self._RainbowGradient.Color = colorSequence

	GuiObject.new(self._RainbowGradient):StartSpin()
end

function GuiObject:StopRotateRainbow()
	if self._RainbowGradient then
		self._RainbowGradient:Destroy()
	end
	self._RainbowGradient = nil

	if self._RainbowConnection then
		self._RainbowConnection:Disconnect()
	end
	self._RainbowConnection = nil
end

function GuiObject:StartSpin()
	self:StopSpin()

	self._SpinConnection = RunService.RenderStepped:Connect(function(dt)
		local totalSpin = self._SpinAngularSpeed * dt

		self._Object.Rotation = self._Object.Rotation + totalSpin
	end)
end

function GuiObject:StopSpin()
	if self._SpinConnection then
		self._SpinConnection:Disconnect()
	end
	self._SpinConnection = nil
end

function GuiObject:MakeShine(width, transparency, color, time, rotation)
	self:StopShine()

	local newFrame = Instance.new("Frame")
	newFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	newFrame.Size = UDim2.fromScale(1, 1)
	newFrame.ZIndex = -100
	newFrame.BorderSizePixel = 0
	newFrame.Parent = self._Object

	local uiCorner = self._Object:FindFirstChildWhichIsA("UICorner")
	if uiCorner then
		local newCorner = uiCorner:Clone()
		newCorner.Parent = newFrame
	end

	self._ShineGradient = newFrame

	local newGradient = Instance.new("UIGradient")
	newGradient.Parent = newFrame

	local middleKeypoint = NumberSequenceKeypoint.new(0.5, transparency)
	local leftKeypoint = NumberSequenceKeypoint.new(0.5 - (width / 2), 1)
	local rightKeypoint = NumberSequenceKeypoint.new(0.5 + (width / 2), 1)
	local leftTransparent = NumberSequenceKeypoint.new(0, 1)
	local rightTransparent = NumberSequenceKeypoint.new(1, 1)

	local numberSequence = NumberSequence.new({
		leftTransparent, leftKeypoint, middleKeypoint, rightKeypoint, rightTransparent
	})

	newGradient.Color = ColorSequence.new(color)
	newGradient.Rotation = rotation or 45
	newGradient.Transparency = numberSequence
	newGradient.Offset = Vector2.new(-1, 0)

	local tween = TweenService:Create(newGradient, TweenInfo.new(time, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {
		Offset = Vector2.new(1 + width, 0)
	})

	tween:Play()

	local connect
	connect = tween.Completed:Connect(function(playbackState)
		connect:Disconnect()

		if playbackState == Enum.PlaybackState.Completed then
			self:StopShine()
		end
	end)

	self._ShineTween = tween
end

function GuiObject:StopShine()
	if self._ShineGradient then
		self._ShineGradient:Destroy()
	end
	self._ShineGradient = nil

	if self._ShineTween then
		self._ShineTween:Cancel()
	end
	self._ShineTween = nil
end

function GuiObject:MakeTextShine(width, color, time, rotation)
	self:StopTextShine()

	if not self._Object:IsA("TextLabel") and not self._Object:IsA("TextButton") then
		warn("MakeTextShine needs a TextLabel or TextButton")
		return
	end

	width = width or 0.25
	color = color or Color3.fromRGB(255, 255, 255)
	time = time or 0.55

	local baseColor = self._Object.TextColor3
	local leftEdge = math.clamp(0.5 - (width / 2), 0, 1)
	local rightEdge = math.clamp(0.5 + (width / 2), 0, 1)
	local gradient = Instance.new("UIGradient")

	self._Object.TextColor3 = Color3.fromRGB(255, 255, 255)
	self._ObjectColorBeforeTextShine = baseColor

	gradient.Name = "TextShineGradient"
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, baseColor),
		ColorSequenceKeypoint.new(leftEdge, baseColor),
		ColorSequenceKeypoint.new(0.5, color),
		ColorSequenceKeypoint.new(rightEdge, baseColor),
		ColorSequenceKeypoint.new(1, baseColor)
	})
	gradient.Rotation = rotation or 20
	gradient.Offset = Vector2.new(-0.5, 0)
	gradient.Parent = self._Object

	local tween = TweenService:Create(gradient, TweenInfo.new(time, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {
		Offset = Vector2.new(0.5, 0)
	})

	tween:Play()

	local connect
	connect = tween.Completed:Connect(function(playbackState)
		connect:Disconnect()

		if playbackState == Enum.PlaybackState.Completed then
			self:StopTextShine()
		end
	end)

	self._TextShineGradient = gradient
	self._TextShineTween = tween
end

function GuiObject:StopTextShine()
	if self._ObjectColorBeforeTextShine then
		self._Object.TextColor3 = self._ObjectColorBeforeTextShine
	end
	self._ObjectColorBeforeTextShine = nil

	if self._TextShineGradient then
		self._TextShineGradient:Destroy()
	end
	self._TextShineGradient = nil

	if self._TextShineTween then
		self._TextShineTween:Cancel()
	end
	self._TextShineTween = nil
end

function GuiObject:RepeatMakeShine(width, transparency, color, time, interval)
	self:StopRepeatMakeShine()

	local accumulator = interval
	self._RepeatShineHeartbeat = RunService.Heartbeat:Connect(function(dt)
		accumulator += dt

		while accumulator >= interval do
			accumulator -= interval
			self:MakeShine(width, transparency, color, time)
		end
	end)
end

function GuiObject:StopRepeatMakeShine()
	if self._RepeatShineHeartbeat then
		self._RepeatShineHeartbeat:Disconnect()
		self._RepeatShineHeartbeat = nil
	end
end

function GuiObject:TweenScale(scale, tweenInfo)
	local tween = TweenService:Create(self._Object, tweenInfo, {
		Size = UDim2.new(
			self._ObjectOriginalSize.X.Scale * scale,
			self._ObjectOriginalSize.X.Offset * scale,
			self._ObjectOriginalSize.Y.Scale * scale,
			self._ObjectOriginalSize.Y.Offset * scale
		)
	})

	tween:Play()
end

function GuiObject:MakeShake(magnitude, duration)
	self:StopShake()

	local originalPos = self._ObjectOriginalPosition
	local startTime = tick()

	-- Connection to RunService
	self._ShakeConnect = RunService.Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		if elapsed > duration then
			-- End shake, reset position
			self._Object.Position = originalPos
			self._ShakeConnect:Disconnect()
			return
		end

		-- Random offset scaled down over time
		local decay = 1 - (elapsed / duration)
		local offsetX = (math.random() - 0.5) * 2 * magnitude * decay
		local offsetY = (math.random() - 0.5) * 2 * magnitude * decay

		self._Object.Position = originalPos + UDim2.fromScale(offsetX, offsetY)
	end)
end

function GuiObject:StopShake()
	if self._ShakeConnect then
		self._ShakeConnect:Disconnect()
	end
	self._ShakeConnect = nil
end

function GuiObject:MakeThrob(scaleFactor: number, duration: number)
	local originalSize = self._ObjectOriginalSize

	self._Object.Size = originalSize

	local enlargedSize = UDim2.new(
		originalSize.X.Scale * scaleFactor,
		originalSize.X.Offset * scaleFactor,
		originalSize.Y.Scale * scaleFactor,
		originalSize.Y.Offset * scaleFactor
	)

	local tweenInfo = TweenInfo.new(duration / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tweenInfoBack = TweenInfo.new(duration / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	-- First tween: grow
	local tweenGrow = TweenService:Create(self._Object, tweenInfo, {Size = enlargedSize})
	tweenGrow:Play()

	tweenGrow.Completed:Once(function()
		-- Second tween: shrink back
		local tweenShrink = TweenService:Create(self._Object, tweenInfoBack, {Size = originalSize})
		tweenShrink:Play()
	end)
end

function GuiObject:StartPulse(callback, scaleFactor: number?, duration: number?, beatGap: number?, restTime: number?)
	if not self._ObjectOriginalSize then return end

	self:StopPulse()

	scaleFactor = scaleFactor or 1.1
	duration = duration or 0.18
	beatGap = beatGap or 0.08
	restTime = restTime or 0.8

	self._PulseTask = task.spawn(function()
		while true do
			for _ = 1, 2 do
				if callback then
					task.spawn(callback)
				end

				self:MakeThrob(scaleFactor, duration)
				task.wait(duration + beatGap)
			end

			task.wait(restTime)
		end
	end)
end

function GuiObject:StopPulse()
	if self._PulseTask then
		task.cancel(self._PulseTask)
	end
	self._PulseTask = nil

	if self._ObjectOriginalSize then
		self._Object.Size = self._ObjectOriginalSize
	end
end

function GuiObject:MakeWiggle(angle : number, wiggles : number, timePerWiggle : number)
	self:StopWiggle()

	self._WiggleTask = task.spawn(function()
		local direction = (math.random(0, 1) * 2) - 1
		for i = 1, wiggles do
			local totalAngle = angle * direction
			local newRotation = self._ObjectOriginalRotation + totalAngle

			local wiggleTime = timePerWiggle
			local tweenInfo = TweenInfo.new(wiggleTime)
			local tween = TweenService:Create(self._Object, tweenInfo, {
				Rotation = newRotation
			})

			tween:Play()
			tween.Completed:Wait()

			direction *= -1
		end

		local tweenInfo = TweenInfo.new(timePerWiggle)
		local tween = TweenService:Create(self._Object, tweenInfo, {
			Rotation = self._ObjectOriginalRotation
		})
		tween:Play()
	end)
end

function GuiObject:StopWiggle()
	if self._WiggleTask then
		task.cancel(self._WiggleTask)
	end
	self._WiggleTask = nil
end

function GuiObject:Blink(blinkCount: number?, onTime: number?, offTime: number?)
	blinkCount = blinkCount or 3
	onTime = onTime or 0.1
	offTime = offTime or 0.1

	task.spawn(function()
		for _ = 1, blinkCount do
			self._Object.Visible = true
			task.wait(onTime)

			self._Object.Visible = false
			task.wait(offTime)
		end

		self._Object.Visible = false
	end)
end

function GuiObject:GrowAndFade(scaleMultiplier: number, tweenInfo : TweenInfo, zIndex : number?)
	local frame = self._Object

	local clone = frame:Clone()
	clone.Visible = true
	clone.Parent = frame.Parent
	clone.ZIndex = zIndex or frame.ZIndex - 1

	for _, child in pairs(clone:GetChildren()) do
		if child:IsA("UIStroke") then
			child:Destroy()
		end
	end

	-- Ensure AnchorPoint is centered for clean scaling
	clone.AnchorPoint = Vector2.new(0.5, 0.5)
	clone.Position = frame.Position

	-- Add UIScale for smooth scaling
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1
	uiScale.Parent = clone

	-- Tween goals
	tweenInfo = tweenInfo or TweenInfo.new(
		1,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	local scaleTween = TweenService:Create(
		uiScale,
		tweenInfo,
		{ Scale = scaleMultiplier }
	)

	local transparencyTween
	if clone:IsA("Frame") then
		transparencyTween = TweenService:Create(
			clone,
			tweenInfo,
			{
				BackgroundTransparency = 1
			}
		)
	elseif clone:IsA("ImageLabel") or clone:IsA("ImageButton") then
		transparencyTween = TweenService:Create(
			clone,
			tweenInfo,
			{
				BackgroundTransparency = 1,
				ImageTransparency = 1
			}
		)
	end

	scaleTween:Play()
	transparencyTween:Play()

	transparencyTween.Completed:Once(function()
		clone:Destroy()
	end)
end

function GuiObject:GrowFrameOutlineAndFade(scaleMultiplier: number?, tweenInfo: TweenInfo?, zIndex: number?)
	local frame = self._Object

	scaleMultiplier = scaleMultiplier or 1.35
	tweenInfo = tweenInfo or TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local clone = Instance.new("Frame")
	clone.Name = frame.Name .. "GrowOutline"
	clone.AnchorPoint = frame.AnchorPoint
	clone.Position = frame.Position
	clone.Size = self._ObjectOriginalSize
	clone.Rotation = frame.Rotation
	clone.BackgroundTransparency = 1
	clone.BorderSizePixel = 0
	clone.ZIndex = zIndex or math.max(frame.ZIndex - 1, 0)
	clone.Visible = true
	clone.Parent = frame.Parent

	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("UICorner") or child:IsA("UIStroke") then
			child:Clone().Parent = clone
		end
	end

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1
	uiScale.Parent = clone

	local scaleTween = TweenService:Create(uiScale, tweenInfo, {
		Scale = scaleMultiplier
	})
	local fadeTween = TweenService:Create(clone, tweenInfo, {
		BackgroundTransparency = 1
	})

	scaleTween:Play()
	fadeTween:Play()

	for _, child in ipairs(clone:GetChildren()) do
		if child:IsA("UIStroke") then
			local strokeTween = TweenService:Create(child, tweenInfo, {
				Transparency = 1
			})
			strokeTween:Play()
		end
	end

	scaleTween.Completed:Once(function()
		clone:Destroy()
	end)

	return clone
end

function GuiObject:RepeatGrowFrameOutlineAndFade(scaleMultiplier: number?, tweenInfo: TweenInfo?, zIndex: number?, interval: number)
	self:StopRepeatGrowFrameOutlineAndFade()

	local accumulator = interval
	self._RepeatGrowFrameOutlineHeartbeat = RunService.Heartbeat:Connect(function(dt)
		accumulator += dt

		while accumulator >= interval do
			accumulator -= interval
			self:GrowFrameOutlineAndFade(scaleMultiplier, tweenInfo, zIndex)
		end
	end)
end

function GuiObject:StopRepeatGrowFrameOutlineAndFade()
	if self._RepeatGrowFrameOutlineHeartbeat then
		self._RepeatGrowFrameOutlineHeartbeat:Disconnect()
		self._RepeatGrowFrameOutlineHeartbeat = nil
	end
end

function GuiObject:RepeatGrowAndFade(scaleMultiplier: number, tweenInfo: TweenInfo, interval: number)
	self:StopRepeatGrowAndFade()

	local accumulator = interval
	self._RepeatGrowFadeHeartbeat = RunService.Heartbeat:Connect(function(dt)
		accumulator += dt

		-- Fire effect on interval
		while accumulator >= interval do
			accumulator -= interval
			self:GrowAndFade(scaleMultiplier, tweenInfo)
		end
	end)
end

function GuiObject:StopRepeatGrowAndFade()
	if self._RepeatGrowFadeHeartbeat then
		self._RepeatGrowFadeHeartbeat:Disconnect()
		self._RepeatGrowFadeHeartbeat = nil
	end
end

return GuiObject
