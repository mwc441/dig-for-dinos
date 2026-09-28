local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local ClientAssets = Assets:WaitForChild("ClientAssets")
local TutorialBoxTemplate = ClientAssets:WaitForChild("TutorialBox")

local DEFAULT_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DEFAULT_DISPLAY_ORDER = 10000

local TutorialBox = {}
TutorialBox.__index = TutorialBox

function TutorialBox.new(parent: Instance?)
	local self = {}
	setmetatable(self, TutorialBox)

	self._OwnsParent = parent == nil
	self._Parent = parent or self:_CreateScreenGui()
	self._TweenInfo = DEFAULT_TWEEN_INFO
	self._ScaleMultiplier = 1
	self._Tween = nil
	self._FrameConnections = {}

	self._Box = TutorialBoxTemplate:Clone()
	self._Box.Visible = false
	self._Box.Parent = self._Parent

	return self
end

function TutorialBox:_CreateScreenGui(): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TutorialBoxGui"
	screenGui.DisplayOrder = DEFAULT_DISPLAY_ORDER
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.ClipToDeviceSafeArea = false
	screenGui.Parent = Player:WaitForChild("PlayerGui")

	return screenGui
end

function TutorialBox:_GetParentAbsolutePosition(): Vector2
	if self._Parent:IsA("GuiObject") then
		return self._Parent.AbsolutePosition
	end

	return Vector2.zero
end

function TutorialBox:_TweenTo(goal, tweenInfo: TweenInfo?)
	if self._Tween then
		self._Tween:Cancel()
	end

	self._Tween = TweenService:Create(self._Box, tweenInfo or self._TweenInfo, goal)
	self._Tween:Play()

	return self._Tween
end

function TutorialBox:_ClearFrameConnections()
	for _, connection in ipairs(self._FrameConnections) do
		connection:Disconnect()
	end

	table.clear(self._FrameConnections)
end

function TutorialBox:GetObject(): GuiObject
	return self._Box
end

function TutorialBox:SetTweenInfo(tweenInfo: TweenInfo)
	self._TweenInfo = tweenInfo
end

function TutorialBox:SetScaleMultiplier(scaleMultiplier: number)
	self._ScaleMultiplier = scaleMultiplier or 1
end

function TutorialBox:SetVisible(visible: boolean)
	self._Box.Visible = visible
end

function TutorialBox:StopTrackingFrame()
	self:_ClearFrameConnections()
end

function TutorialBox:Show()
	self:SetVisible(true)
end

function TutorialBox:Hide()
	self:SetVisible(false)
end

function TutorialBox:_GetMoveAndResizeOptions(scaleMultiplier: number | TweenInfo?, tweenInfo: TweenInfo?)
	if typeof(scaleMultiplier) == "TweenInfo" then
		return self._ScaleMultiplier, scaleMultiplier
	end

	return scaleMultiplier or self._ScaleMultiplier, tweenInfo
end

function TutorialBox:_MoveAndResize(absolutePosition: Vector2, absoluteSize: Vector2, scaleMultiplier: number | TweenInfo?, tweenInfo: TweenInfo?)
	local resolvedScaleMultiplier, resolvedTweenInfo = self:_GetMoveAndResizeOptions(scaleMultiplier, tweenInfo)
	local scaledSize = absoluteSize * resolvedScaleMultiplier
	local scaledPosition = absolutePosition - ((scaledSize - absoluteSize) / 2)
	local parentPosition = self:_GetParentAbsolutePosition()
	local anchorPoint = self._Box.AnchorPoint
	local position = scaledPosition - parentPosition + GuiService:GetGuiInset() + Vector2.new(
		scaledSize.X * anchorPoint.X,
		scaledSize.Y * anchorPoint.Y
	)

	return self:_TweenTo({
		Position = UDim2.fromOffset(position.X, position.Y),
		Size = UDim2.fromOffset(scaledSize.X, scaledSize.Y)
	}, resolvedTweenInfo)
end

function TutorialBox:MoveAndResize(absolutePosition: Vector2, absoluteSize: Vector2, scaleMultiplier: number | TweenInfo?, tweenInfo: TweenInfo?)
	self:StopTrackingFrame()

	return self:_MoveAndResize(absolutePosition, absoluteSize, scaleMultiplier, tweenInfo)
end

function TutorialBox:MoveAndResizeToFrame(frame: GuiObject, scaleMultiplier: number | TweenInfo?, tweenInfo: TweenInfo?)
	self:StopTrackingFrame()

	local function update()
		self:_MoveAndResize(frame.AbsolutePosition, frame.AbsoluteSize, scaleMultiplier, tweenInfo)
	end

	table.insert(self._FrameConnections, frame:GetPropertyChangedSignal("AbsolutePosition"):Connect(update))
	table.insert(self._FrameConnections, frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))

	update()
end

function TutorialBox:Destroy()
	self:StopTrackingFrame()

	if self._Tween then
		self._Tween:Cancel()
	end
	self._Tween = nil

	if self._Box then
		self._Box:Destroy()
	end
	self._Box = nil

	if self._OwnsParent and self._Parent then
		self._Parent:Destroy()
	end
	self._Parent = nil
end

return TutorialBox
