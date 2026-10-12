local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Dinosaurs = Assets:WaitForChild("Dinosaurs")
local MutationsEnum = require(ReplicatedStorage:WaitForChild("Enums"):WaitForChild("Mutations"))
local DinosaurDef = require(ReplicatedStorage:WaitForChild("ReplicatedConfigs"):WaitForChild("DinosaurDef"))
local BonePileUtils = require(script.Parent:WaitForChild("BonePileUtils"))
local MutationUtils = require(script.Parent:WaitForChild("MutationUtils"))
local UtilFunctions = require(script.Parent:WaitForChild("UtilFunctions"))

local DinosaurUtils = {}

function DinosaurUtils.CreateModel(dinosaurId, scale, mutation): Model?
	if not DinosaurDef.GetDinosaurInfo(dinosaurId) then
		warn("Unknown dinosaur model: " .. tostring(dinosaurId))
		return
	end

	local template = Dinosaurs:FindFirstChild(dinosaurId)
	if not template or not template:IsA("Model") then
		warn("Missing dinosaur model: " .. dinosaurId)
		return
	end

	local model = template:Clone()
	scale = BonePileUtils.GetScale(scale)
	if mutation then
		MutationUtils.Apply(model, mutation)
	end
	model:ScaleTo(scale)
	UtilFunctions.AnchorAllDescendants(model, false)
	model.PrimaryPart.Anchored = true
	UtilFunctions.CanCollideAllDescendants(model, false)
	UtilFunctions.CanQueryAllDescendants(model, true)
	UtilFunctions.CanTouchAllDescendants(model, true)
	model:SetAttribute("DinosaurId", dinosaurId)
	model:SetAttribute("Scale", scale)
	model:SetAttribute("Mutation", mutation or MutationsEnum.Normal)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	return model
end

function DinosaurUtils.PositionAtGround(model: Model, groundCFrame: CFrame)
	local _, boundsSize = model:GetBoundingBox()
	local targetBounds = groundCFrame * CFrame.new(0, boundsSize.Y / 2, 0)
	UtilFunctions.MoveModelByBoundingBox(model, targetBounds)
end

function DinosaurUtils.LoadAnimation(model: Model, animationName: string): AnimationTrack?
	local animation = model:FindFirstChild(animationName, true)
	if not animation or not animation:IsA("Animation") then return end

	local animator = model:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		local animationController = model:FindFirstChildWhichIsA("AnimationController", true)
			or model:FindFirstChildWhichIsA("Humanoid", true)
		if not animationController then
			animationController = Instance.new("AnimationController")
			animationController.Parent = model
		end

		animator = Instance.new("Animator")
		animator.Parent = animationController
	end

	return animator:LoadAnimation(animation)
end

function DinosaurUtils.CreateViewportModel(viewportFrame: ViewportFrame, dinosaurId, scale, mutation)
	local model = DinosaurUtils.CreateModel(dinosaurId, scale, mutation)
	if not model then return end

	local worldModel = Instance.new("WorldModel")
	worldModel.Name = "DinosaurPreview"
	worldModel.Parent = viewportFrame
	model:PivotTo(model:GetPivot().Rotation)
	model.Parent = worldModel
	local idleTrack = DinosaurUtils.LoadAnimation(model, "Idle")
	if idleTrack then
		idleTrack.Looped = true
		idleTrack.Priority = Enum.AnimationPriority.Idle
		idleTrack:Play()
	end

	local camera = Instance.new("Camera")
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 35
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera

	local function updateCamera()
		local boundsCFrame, boundsSize = model:GetBoundingBox()

		local distance = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z) * 0.8
		local cameraCFrame = boundsCFrame * CFrame.Angles(0, math.rad(30), 0) * CFrame.new(0, 0, -distance) * CFrame.Angles(0, math.rad(180), 0)
		cameraCFrame = cameraCFrame + (boundsCFrame.LookVector * distance * 0.3)
		camera.CFrame = cameraCFrame
	end

	updateCamera()

	return worldModel, camera
end

return DinosaurUtils
