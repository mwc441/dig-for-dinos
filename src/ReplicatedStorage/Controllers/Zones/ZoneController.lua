local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer

local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local External = ReplicatedStorage:WaitForChild("External")
local Components = ReplicatedStorage:WaitForChild("Components")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local ZoneDef = require(ReplicatedConfigs:WaitForChild("ZoneDef"))
local Knit = require(External:WaitForChild("Knit"))

local ZoneController = {
	Name = "ZoneController"
}

function ZoneController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local hud = mainGui:WaitForChild("Hud")

	self._Gui = {
		ZoneFrame = hud:WaitForChild("ZoneFrame")
	}

	self._ZoneFrameOriginalPos = self._Gui.ZoneFrame.Position
end

function ZoneController:KnitStart()
	self._Zone2dComponent = require(Components.Zone2d)

	self._Zone2dComponent.EnteredZone:Connect(function(zone)
		local name = zone.Instance.Name
		local info = ZoneDef.GetZoneInfo(name)
		if not info then return end

		self:_EnteredZone(name)
	end)

	self._Zone2dComponent.ExitedZone:Connect(function(zone)
		local name = zone.Instance.Name
		local info = ZoneDef.GetZoneInfo(name)
		if not info then return end

		self:_ExitedZone(name)
	end)
end

function ZoneController:_EnteredZone(zoneId)
	local info = ZoneDef.GetZoneInfo(zoneId)
	if not info then return end

	if not self._TweensPlaying then
		self._TweensPlaying = {}
	end

	for _, tween in pairs(self._TweensPlaying) do
		tween:Cancel()
	end
	self._TweensPlaying = {}

	if self._HideTask then
		task.cancel(self._HideTask)
	end

	local zoneText = self._Gui.ZoneFrame.ZoneText
	local leftEmoji = self._Gui.ZoneFrame.LeftEmoji
	local rightEmoji = self._Gui.ZoneFrame.RightEmoji

	zoneText.UIGradient.Color = info.Color or ColorSequence.new(Color3.fromRGB(255, 255, 255))
	zoneText.Text = info.Name or ""
	leftEmoji.Text = info.Emoji or ""
	rightEmoji.Text = info.Emoji or ""

	self._Gui.ZoneFrame.Position = self._ZoneFrameOriginalPos - UDim2.fromScale(0, 0.035)

	local showTweenInfo = TweenInfo.new(0.35)
	local hideTweenInfo = TweenInfo.new(0.5)

	local showTween, showNumberVal = UtilFunctions.TweenNumberValue(1, 0, showTweenInfo)
	showNumberVal.Changed:Connect(function(value)
		UtilFunctions.SetGuiTransparencyDescendants(self._Gui.ZoneFrame, value)
	end)
	local positionTween = TweenService:Create(self._Gui.ZoneFrame, showTweenInfo, {
		Position = self._ZoneFrameOriginalPos
	})

	local hideTween, hideNumberVal = UtilFunctions.TweenNumberValue(0, 1, hideTweenInfo)
	hideNumberVal.Changed:Connect(function(value)
		UtilFunctions.SetGuiTransparencyDescendants(self._Gui.ZoneFrame, value)
	end)

	table.insert(self._TweensPlaying, positionTween)
	table.insert(self._TweensPlaying, showTween)
	table.insert(self._TweensPlaying, hideTween)

	positionTween:Play()
	showTween:Play()

	showTween.Completed:Connect(function(playbackState)
		if playbackState ~= Enum.PlaybackState.Completed then return end

		self._HideTask = task.delay(2, function()
			hideTween:Play()
			self._HideTask = nil
		end)
	end)
	hideTween.Completed:Connect(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed then
			self._TweensPlaying = {}
		end
	end)
end

function ZoneController:_ExitedZone(zoneId)
end

return ZoneController