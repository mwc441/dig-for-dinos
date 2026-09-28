local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local External = ReplicatedStorage:WaitForChild("External")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local ClientAssets = Assets:WaitForChild("ClientAssets")
local ProximityGui = ClientAssets:WaitForChild("ProximityGui")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local Knit = require(External:WaitForChild("Knit"))

local ORIGINAL_SIZE = ProximityGui.Size

local ProximityController = {
	Name = "ProximityController",
	_PromptGuis = {},
	_PromptTweens = {},
	_PromptHoldHeartbeats = {}
}

function ProximityController:KnitInit()
	local playerGui = Player:WaitForChild("PlayerGui")

	local newGui = Instance.new("ScreenGui")
	newGui.ResetOnSpawn = false
	newGui.Enabled = true
	newGui.IgnoreGuiInset = true
	newGui.Name = "_ProximityPrompts"
	newGui.Parent = playerGui

	self._ProximityGui = newGui

	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		prompt.Style = Enum.ProximityPromptStyle.Custom

		if not prompt:GetAttribute("NoShow") then
			self:_SetupGui(prompt, inputType)
		end
	end)

	ProximityPromptService.PromptHidden:Connect(function(prompt)
		local proximityGui = self._PromptGuis[prompt]
		if proximityGui then
			local tweenInfo = TweenInfo.new(0.14)
			local tween = TweenService:Create(proximityGui, tweenInfo, {
				Size = UDim2.fromScale(0, 0)
			})

			tween:Play()
			tween.Completed:Connect(function()
				proximityGui:Destroy()
			end)
		end

		self._PromptGuis[prompt] = nil
	end)

	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		if prompt.HoldDuration > 0 then
			self:_PromptHeldDown(prompt)
		end
	end)

	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		if prompt.HoldDuration > 0 then
			self:_PromptReleased(prompt)
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.HoldDuration <= 0 then
			self:_PromptHeldDown(prompt)
		else
			self:_PromptReleased(prompt)
		end
	end)

	ProximityPromptService.PromptTriggerEnded:Connect(function(prompt)
		if prompt.HoldDuration <= 0 then
			self:_PromptReleased(prompt)
		end
	end)
end

function ProximityController:_SetupGui(prompt, inputType)
	local newGui = ProximityGui:Clone()

	if inputType == Enum.ProximityPromptInputType.Touch then
		newGui.Button.ButtonText.Text = ""
	elseif inputType == Enum.ProximityPromptInputType.Keyboard then
		newGui.Button.ButtonText.Text = prompt.KeyboardKeyCode.Name
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		newGui.Button.ButtonText.Text = ""
		newGui.Button.GamepadIcon:SetAttribute("KeyCode", prompt.GamepadKeyCode)
		CollectionService:AddTag(newGui.Button.GamepadIcon, "GamepadIcon")
	end

	local isTouch = (inputType == Enum.ProximityPromptInputType.Touch)
	newGui.Button.TapIcon.Visible = isTouch
	newGui.Button.MobileBackground.Visible = isTouch
	newGui.Button.TextBackground.Visible = not isTouch

	newGui.Button.ObjectText.Text = prompt.ObjectText or ""
	newGui.Button.ActionText.Text = prompt.ActionText or ""

	local size = prompt:GetAttribute("Size") or ORIGINAL_SIZE
	newGui.Size = UDim2.fromScale(0, 0)

	local tweenInfo = TweenInfo.new(0.14)
	local tween = TweenService:Create(newGui, tweenInfo, {
		Size = size
	})

	tween:Play()

	newGui.Button.MouseButton1Down:Connect(function()
		prompt:InputHoldBegin()

		local connection
		connection = UserInputService.InputEnded:Connect(function(input, gpe)
			if (input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch) then
				connection:Disconnect()
				prompt:InputHoldEnd()
			end
		end)
	end)

	newGui.Adornee = prompt.Parent
	newGui.Parent = self._ProximityGui

	self._PromptGuis[prompt] = newGui
end

function ProximityController:_PromptHeldDown(prompt : ProximityPrompt)
	if self._PromptTweens[prompt] then
		self._PromptTweens[prompt]:Cancel()
		self._PromptTweens[prompt] = nil
	end

	local proximityGui = self._PromptGuis[prompt]
	if not proximityGui then
		return
	end

	local scale = 0.8

	local size = prompt:GetAttribute("Size") or ORIGINAL_SIZE
	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
	local tween = TweenService:Create(proximityGui, tweenInfo, {
		Size = UDim2.new(size.X.Scale * scale, size.X.Offset * scale, size.Y.Scale * scale, size.Y.Offset * scale)
	})

	self._PromptTweens[prompt] = tween

	tween:Play()

	local holdDuration = prompt.HoldDuration

	if holdDuration > 0 then
		local circle = proximityGui.Button.Circle

		local total = 0
		self._PromptHoldHeartbeats[prompt] = RunService.Heartbeat:Connect(function(dt)
			total += dt

			local percentage = math.clamp(total / holdDuration, 0, 1)

			UtilFunctions.SetPercentageForCircleClockwise(circle, percentage)

			circle.Visible = true
		end)
	end
end

function ProximityController:_PromptReleased(prompt)
	if self._PromptTweens[prompt] then
		self._PromptTweens[prompt]:Cancel()
		self._PromptTweens[prompt] = nil
	end

	if self._PromptHoldHeartbeats[prompt] then
		self._PromptHoldHeartbeats[prompt]:Disconnect()
		self._PromptHoldHeartbeats[prompt] = nil
	end

	local proximityGui = self._PromptGuis[prompt]
	if not proximityGui then
		return
	end

	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
	local tween = TweenService:Create(proximityGui, tweenInfo, {
		Size = prompt:GetAttribute("Size") or ORIGINAL_SIZE
	})

	self._PromptTweens[prompt] = tween

	local holdDuration = prompt.HoldDuration

	if holdDuration > 0 then
		local circle = proximityGui.Button.Circle

		UtilFunctions.SetPercentageForCircleClockwise(circle, 0)
		circle.Visible = false
	end

	tween:Play()
end

return ProximityController