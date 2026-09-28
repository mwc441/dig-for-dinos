local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local External = ReplicatedStorage:WaitForChild("External")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local GuiObject = require(GuiModules:WaitForChild("Object"))
local Knit = require(External:WaitForChild("Knit"))

local UiTagController = {
	Name = "UiTagController"
}

function UiTagController:KnitInit()
	self:_SetupMakeRainbows()
	self:_SetupMakeRotateLeftAndRights()
	self:_SetupMakeSparkle()
	self:_SetupMakeRotate()
	self:_SetupMakeFloatUpAndDowns()
	self:_SetupMakeTweenThroughRainbow()
	self:_SetupMakeRotateRainbows()
end

function UiTagController:_SetupMakeRainbows()
	for _, makeRainbow in pairs(CollectionService:GetTagged("UI_Make_Rainbow")) do
		self:_SetupMakeRainbow(makeRainbow)
	end

	CollectionService:GetInstanceAddedSignal("UI_Make_Rainbow"):Connect(function(makeRainbow)
		self:_SetupMakeRainbow(makeRainbow)
	end)
end

function UiTagController:_SetupMakeRainbow(makeRainbow)
	local saturation = makeRainbow:GetAttribute("Saturation")
	local value = makeRainbow:GetAttribute("Value")

	local object = GuiObject.new(makeRainbow)
	object:MakeRainbow(saturation, value)
end

function UiTagController:_SetupMakeRotateLeftAndRights()
	for _, rotateLeftRight in pairs(CollectionService:GetTagged("UI_Make_Rotate_Left_Right")) do
		self:_SetupMakeRotateLeftAndRight(rotateLeftRight)
	end

	CollectionService:GetInstanceAddedSignal("UI_Make_Rotate_Left_Right"):Connect(function(rotateLeftRight)
		self:_SetupMakeRotateLeftAndRight(rotateLeftRight)
	end)
end

function UiTagController:_SetupMakeRotateLeftAndRight(rotateLeftRight)
	local object = GuiObject.new(rotateLeftRight)
	local rotateTime = rotateLeftRight:GetAttribute("Time")
	local rotateAngle = rotateLeftRight:GetAttribute("Angle")
	if rotateTime then
		object:SetRotateLeftRightTime(rotateTime)
	end

	if rotateAngle then
		object:SetRotateLeftRightAngle(rotateAngle)
	end
	object:MakeRotateLeftRight()
end

function UiTagController:_SetupMakeSparkle()
	for _, makeSparkle in pairs(CollectionService:GetTagged("UI_Make_Sparkle")) do
		local object = GuiObject.new(makeSparkle)
		object:MakeSparkle()
	end

	CollectionService:GetInstanceAddedSignal("UI_Make_Sparkle"):Connect(function(makeSparkle)
		local object = GuiObject.new(makeSparkle)
		object:MakeSparkle()
	end)
end

function UiTagController:_SetupMakeRotate()
	for _, rotate in pairs(CollectionService:GetTagged("UI_Make_Rotate")) do
		local spinSpeed = rotate:GetAttribute("SpinSpeed")

		local object = GuiObject.new(rotate)
		if spinSpeed then
			object:SetSpinAngularSpeed(spinSpeed)
		end
		object:StartSpin()
	end

	CollectionService:GetInstanceAddedSignal("UI_Make_Rotate"):Connect(function(rotate)
		local spinSpeed = rotate:GetAttribute("SpinSpeed")

		local object = GuiObject.new(rotate)
		if spinSpeed then
			object:SetSpinAngularSpeed(spinSpeed)
		end
		object:StartSpin()
	end)
end

function UiTagController:_SetupMakeFloatUpAndDowns()
	for _, makeFloatUpAndDown in pairs(CollectionService:GetTagged("UI_Make_Float_Up_And_Down")) do
		self:_SetupMakeFloatUpAndDown(makeFloatUpAndDown)
	end

	CollectionService:GetInstanceAddedSignal("UI_Make_Float_Up_And_Down"):Connect(function(makeFloatUpAndDown)
		self:_SetupMakeFloatUpAndDown(makeFloatUpAndDown)
	end)
end

function UiTagController:_SetupMakeFloatUpAndDown(makeFloatUpAndDown)
	local floatScale = makeFloatUpAndDown:GetAttribute("FloatScale")
	local floatHalfTime = makeFloatUpAndDown:GetAttribute("FloatHalfTime")

	local object = GuiObject.new(makeFloatUpAndDown)
	if floatScale then
		object:SetFloatScale(floatScale)
	end

	if floatHalfTime then
		object:SetFloatHalfTime(floatHalfTime)
	end
	object:MakeFloatUpAndDown()
end

function UiTagController:_SetupMakeTweenThroughRainbow()
	for _, makeRainbow in pairs(CollectionService:GetTagged("UI_Make_Tween_Through_Rainbow")) do
		local object = GuiObject.new(makeRainbow)
		object:MakeTweenThroughRainbow()
	end

	CollectionService:GetInstanceAddedSignal("UI_Make_Tween_Through_Rainbow"):Connect(function(makeRainbow)
		local object = GuiObject.new(makeRainbow)
		object:MakeTweenThroughRainbow()
	end)
end

function UiTagController:_SetupMakeRotateRainbows()
for _, makeRainbow in pairs(CollectionService:GetTagged("UI_Make_Rotate_Rainbow")) do
		local object = GuiObject.new(makeRainbow)
		object:MakeRotateRainbow()
	end

	CollectionService:GetInstanceAddedSignal("UI_Make_Rotate_Rainbow"):Connect(function(makeRainbow)
		local object = GuiObject.new(makeRainbow)
		object:MakeRotateRainbow()
	end)
end

return UiTagController
