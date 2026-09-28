local Lighting = game:GetService("Lighting")
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
end

-- HUD STUFF
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
