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
	_PromptStates = {}
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
		self:_CleanupPrompt(prompt, true)
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
	self:_CleanupPrompt(prompt)

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
	newGui.Adornee = prompt.Parent
	newGui.Parent = self._ProximityGui

	local state = {
		Gui = newGui
	}
	self._PromptStates[prompt] = state
	state.Destroying = prompt.Destroying:Connect(function()
		self:_CleanupPrompt(prompt)
	end)

	self:_TweenGui(state, TweenInfo.new(0.14), size)

	newGui.Button.MouseButton1Down:Connect(function()
		if self._PromptStates[prompt] ~= state or state.Hidden then
			return
		end

		if state.InputEnded then
			state.InputEnded:Disconnect()
			state.InputEnded = nil
		end

		state.InputEnded = UserInputService.InputEnded:Connect(function(input)
			if (input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch) then
				state.InputEnded:Disconnect()
				state.InputEnded = nil
				if self._PromptStates[prompt] == state and not state.Hidden then
					prompt:InputHoldEnd()
				end
			end
		end)

		prompt:InputHoldBegin()
	end)
end

function ProximityController:_PromptHeldDown(prompt : ProximityPrompt)
	local state = self._PromptStates[prompt]
	if not state or state.Hidden then
		return
	end

	local proximityGui = state.Gui
	local scale = 0.8

	local size = prompt:GetAttribute("Size") or ORIGINAL_SIZE
	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
	self:_TweenGui(state, tweenInfo, UDim2.new(size.X.Scale * scale, size.X.Offset * scale, size.Y.Scale * scale, size.Y.Offset * scale))

	local holdDuration = prompt.HoldDuration

	if holdDuration > 0 then
		if state.HoldHeartbeat then
			state.HoldHeartbeat:Disconnect()
		end

		local circle = proximityGui.Button.Circle

		proximityGui.Button.ActionText.Text = string.format("%.1fs", holdDuration)

		local total = 0
		state.HoldHeartbeat = RunService.Heartbeat:Connect(function(dt)
			total += dt

			local percentage = math.clamp(total / holdDuration, 0, 1)

			UtilFunctions.SetPercentageForCircleClockwise(circle, percentage)
			proximityGui.Button.ActionText.Text = string.format("%.1fs", math.max(holdDuration - total, 0))

			circle.Visible = true
		end)
	end
end

function ProximityController:_PromptReleased(prompt)
	local state = self._PromptStates[prompt]
	if not state or state.Hidden then
		return
	end

	if state.HoldHeartbeat then
		state.HoldHeartbeat:Disconnect()
		state.HoldHeartbeat = nil
	end

	local proximityGui = state.Gui
	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
	self:_TweenGui(state, tweenInfo, prompt:GetAttribute("Size") or ORIGINAL_SIZE)

	local holdDuration = prompt.HoldDuration

	if holdDuration > 0 then
		local circle = proximityGui.Button.Circle

		UtilFunctions.SetPercentageForCircleClockwise(circle, 0)
		proximityGui.Button.ActionText.Text = prompt.ActionText or ""
		circle.Visible = false
	end
end

function ProximityController:_StopTween(state)
	if state.TweenCompleted then
		state.TweenCompleted:Disconnect()
		state.TweenCompleted = nil
	end

	if state.Tween then
		state.Tween:Cancel()
		state.Tween:Destroy()
		state.Tween = nil
	end
end

function ProximityController:_TweenGui(state, tweenInfo, size, onCompleted)
	self:_StopTween(state)

	local tween = TweenService:Create(state.Gui, tweenInfo, {
		Size = size
	})
	state.Tween = tween
	state.TweenCompleted = tween.Completed:Connect(function(playbackState)
		state.TweenCompleted:Disconnect()
		state.TweenCompleted = nil
		state.Tween = nil
		tween:Destroy()

		if playbackState == Enum.PlaybackState.Completed and onCompleted then
			onCompleted()
		end
	end)
	tween:Play()
end

function ProximityController:_CleanupPrompt(prompt, fadeOut)
	local state = self._PromptStates[prompt]
	if not state then
		return
	end

	if state.HoldHeartbeat then
		state.HoldHeartbeat:Disconnect()
		state.HoldHeartbeat = nil
	end

	if state.InputEnded then
		state.InputEnded:Disconnect()
		state.InputEnded = nil
	end

	if fadeOut then
		if not state.Hidden then
			state.Hidden = true
			self:_TweenGui(state, TweenInfo.new(0.14), UDim2.fromScale(0, 0), function()
				self:_CleanupPrompt(prompt)
			end)
		end
		return
	end

	self._PromptStates[prompt] = nil
	state.Destroying:Disconnect()
	self:_StopTween(state)
	state.Gui:Destroy()
end

return ProximityController
