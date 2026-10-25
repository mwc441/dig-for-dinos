local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Dinosaurs = Assets:WaitForChild("Dinosaurs")
local MutationsEnum = require(ReplicatedStorage:WaitForChild("Enums"):WaitForChild("Mutations"))
local DinosaurDef = require(ReplicatedStorage:WaitForChild("ReplicatedConfigs"):WaitForChild("DinosaurDef"))
local BonePileUtils = require(script.Parent:WaitForChild("BonePileUtils"))
local MutationUtils = require(script.Parent:WaitForChild("MutationUtils"))
local UtilFunctions = require(script.Parent:WaitForChild("UtilFunctions"))

local DinosaurUtils = {}
local CachedModels = {}

function DinosaurUtils.CreateModel(dinosaurId, scale, mutation, isViewport: boolean): Model?
	if not DinosaurDef.GetDinosaurInfo(dinosaurId) then
		warn("Unknown dinosaur model: " .. tostring(dinosaurId))
		return
	end

	local template = Dinosaurs:FindFirstChild(dinosaurId)
	if not template or not template:IsA("Model") then
		warn("Missing dinosaur model: " .. dinosaurId)
		return
	end

	local mutationCache = CachedModels[dinosaurId]
	if not mutationCache then
		mutationCache = {}
		CachedModels[dinosaurId] = mutationCache
	end

	local mutationKey = mutation or false
	local variants = mutationCache[mutationKey]
	if not variants then
		variants = {}
		mutationCache[mutationKey] = variants
	end

	local variant = mutation and isViewport and "Viewport" or "World"
	local cachedModel = variants[variant]
	if not cachedModel then
		cachedModel = template:Clone()
		if mutation then
			MutationUtils.Apply(cachedModel, mutation, isViewport)
		end
		UtilFunctions.AnchorAllDescendants(cachedModel, false)
		cachedModel.PrimaryPart.Anchored = true
		UtilFunctions.CanCollideAllDescendants(cachedModel, false)
		UtilFunctions.CanQueryAllDescendants(cachedModel, true)
		UtilFunctions.CanTouchAllDescendants(cachedModel, true)
		cachedModel.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		variants[variant] = cachedModel
	end

	local model = cachedModel:Clone()
	scale = BonePileUtils.GetScale(scale)
	model:ScaleTo(scale)
	model:SetAttribute("DinosaurId", dinosaurId)
	model:SetAttribute("Scale", scale)
	model:SetAttribute("Mutation", mutation or MutationsEnum.Normal)

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
	local model = DinosaurUtils.CreateModel(dinosaurId, scale, mutation, true)
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
	camera.FieldOfViewMode = Enum.FieldOfViewMode.Vertical
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera

	local function updateCamera()
		local boundsCFrame, boundsSize = model:GetBoundingBox()
		local center = boundsCFrame.Position
		local cameraDirection = (boundsCFrame * CFrame.Angles(0, math.rad(30), 0)).LookVector
		local cameraRotation = CFrame.lookAt(center + cameraDirection, center).Rotation
		local viewportSize = viewportFrame.AbsoluteSize
		local aspectRatio = viewportSize.X > 0 and viewportSize.Y > 0 and viewportSize.X / viewportSize.Y or 1
		local tanHalfVerticalFov = math.tan(math.rad(camera.FieldOfView) / 2)
		local tanHalfHorizontalFov = tanHalfVerticalFov * aspectRatio
		local halfSize = boundsSize / 2
		local distance = 0

		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local corner = boundsCFrame:PointToWorldSpace(Vector3.new(halfSize.X * x, halfSize.Y * y, halfSize.Z * z))
					local localCorner = cameraRotation:VectorToObjectSpace(corner - center)
					local cornerDistance = localCorner.Z + math.max(math.abs(localCorner.X) / tanHalfHorizontalFov, math.abs(localCorner.Y) / tanHalfVerticalFov)
					distance = math.max(distance, cornerDistance)
				end
			end
		end

		distance = math.max(distance * 0.9, 1)
		camera.CFrame = CFrame.lookAt(center + cameraDirection * distance, center)
		camera.Focus = CFrame.new(center)
	end

	updateCamera()
	local sizeConnection = viewportFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCamera)
	camera.Destroying:Connect(function()
		sizeConnection:Disconnect()
	end)

	return worldModel, camera
end

return DinosaurUtils
