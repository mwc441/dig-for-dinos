local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local External = ReplicatedStorage:WaitForChild("External")
local Signal = require(External:WaitForChild("Signal"))

local HudController = {
	Name = "HudController",
	_AudioController = nil,
	ActiveFrameChanged = Signal.new(),
}

function HudController:KnitStart()
	self._AudioController = require(ReplicatedStorage.Controllers.Audio.AudioController)

	local clickGui = Instance.new("ScreenGui")
	clickGui.Name = "ClickEffects"
	clickGui.ScreenInsets = Enum.ScreenInsets.None
	clickGui.ResetOnSpawn = false
	clickGui.DisplayOrder = 100
	clickGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self._ClickGui = clickGui

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_ShowClickEffect(input.Position)
		end
	end)

	UserInputService.TouchTap:Connect(function(touchPositions)
		for _, position in touchPositions do
			self:_ShowClickEffect(position)
		end
	end)
end

-- HUD STUFF
function HudController:_ShowClickEffect(position)
	local guiInset = GuiService:GetGuiInset()
	local circle = Instance.new("Frame")
	circle.Name = "ClickCircle"
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.fromOffset(position.X + guiInset.X, position.Y + guiInset.Y)
	circle.Size = UDim2.fromOffset(0, 0)
	circle.BackgroundTransparency = 1
	circle.BorderSizePixel = 0
	circle.Parent = self._ClickGui

	local uiAspectRatio = Instance.new("UIAspectRatioConstraint")
	uiAspectRatio.AspectRatio = 1
	uiAspectRatio.Parent = circle

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = circle

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.FixedSize
	stroke.Thickness = 3
	stroke.Transparency = 0.15
	stroke.Parent = circle

	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local growTween = TweenService:Create(circle, tweenInfo, {
		Size = UDim2.fromScale(0.11, 0.11)
	})
	local fadeTween = TweenService:Create(stroke, tweenInfo, {
		Transparency = 1
	})

	growTween.Completed:Once(function()
		circle:Destroy()
	end)
	growTween:Play()
	fadeTween:Play()
end

function HudController:SetCurrentlyActiveFrame(controller)
	if (not controller) and self._CurrentlyActiveFrame then
		self._CurrentlyActiveFrame:SetVisibility(false)
		return
	elseif not controller then
		return
	end

	if self._CurrentlyActiveFrame == controller then
		return
	end

	local previousController = self._CurrentlyActiveFrame

	self._CurrentlyActiveFrame = controller
	self.ActiveFrameChanged:Fire(controller)

	if previousController then
		previousController:SetVisibility(false)
	else
		self:DoActiveFrameStuff()
	end
end

function HudController:GetCurrentlyActiveFrame()
	return self._CurrentlyActiveFrame
end

function HudController:ClearCurrentlyActiveFrame(controller)
	if self._CurrentlyActiveFrame == controller then
		self._CurrentlyActiveFrame = nil
		self.ActiveFrameChanged:Fire(nil)
		self:UndoActiveFrameStuff()
	end
end

function HudController:BlurScreen(blurTime)
	if self._Blur then
		return
	end

	local blur = Instance.new("BlurEffect")
	blur.Size = 0
	blur.Parent = Lighting
	self._Blur = blur

	local tweenInfo = TweenInfo.new(blurTime or 0.5, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(self._Blur, tweenInfo, {
		Size = 24
	})

	tween:Play()

	return tween
end

function HudController:UnblurScreen(blurTime)
	if self._Blur then
		local blur = self._Blur

		local tweenInfo = TweenInfo.new(blurTime or 0.5, Enum.EasingStyle.Linear)
		local tween = TweenService:Create(blur, tweenInfo, {
			Size = 0
		})

		tween:Play()

		local connect
		connect = tween.Completed:Connect(function()
			connect:Disconnect()
			blur:Destroy()
		end)
	end

	self._Blur = nil
end

function HudController:LowerDepthOfField(distance, intensity, lowerTime)
	if self._Dof then
		return
	end

	local dof = Instance.new("DepthOfFieldEffect")
	dof.InFocusRadius = 0
	dof.NearIntensity = 0
	dof.FocusDistance = distance
	dof.FarIntensity = 0
	dof.Parent = Lighting

	self._Dof = dof

	local tweenInfo = TweenInfo.new(lowerTime)
	local tween = TweenService:Create(dof, tweenInfo, {
		FarIntensity = intensity
	})

	tween:Play()
end

function HudController:RemoveDepthOfField(duration)
	if not self._Dof then
		return
	end

	local dof = self._Dof
	self._Dof = nil

	local tweenInfo = TweenInfo.new(duration)
	local tween = TweenService:Create(dof, tweenInfo, {
		FarIntensity = 0
	})

	tween:Play()

	local connect
	connect = tween.Completed:Connect(function()
		connect:Disconnect()
		dof:Destroy()
	end)
end

function HudController:TweenFov(fov, totalTime)
	local camera = Workspace.CurrentCamera

	local tweenInfo = TweenInfo.new(totalTime)
	local tween = TweenService:Create(camera, tweenInfo, {
		FieldOfView = fov
	})
	tween:Play()
end

function HudController:BlurSound(totalTime)
	self._AudioController:BlurSound(totalTime)
end

function HudController:UnblurSound(totalTime)
	self._AudioController:UnblurSound(true, totalTime)
end

function HudController:DoActiveFrameStuff()
	if self._BackButtonConnect then
		self._BackButtonConnect:Disconnect()
	end

	if self._BackButtonBeganConnect then
		self._BackButtonBeganConnect:Disconnect()
	end

	self._BackButtonInput = nil

	self._BackButtonBeganConnect = UserInputService.InputBegan:Connect(function(input, gpe)
		if input.KeyCode ~= Enum.KeyCode.ButtonB then return end

		self._BackButtonInput = if gpe then nil else input
	end)

	self._BackButtonConnect = UserInputService.InputEnded:Connect(function(input, gpe)
		if input.KeyCode ~= Enum.KeyCode.ButtonB then return end

		local beganInput = self._BackButtonInput
		self._BackButtonInput = nil

		if beganInput == input and not gpe then
			self:SetCurrentlyActiveFrame(nil)
		end
	end)
end

function HudController:UndoActiveFrameStuff()
	if self._BackButtonBeganConnect then
		self._BackButtonBeganConnect:Disconnect()
	end

	if self._BackButtonConnect then
		self._BackButtonConnect:Disconnect()
	end

	self._BackButtonInput = nil
end

return HudController
