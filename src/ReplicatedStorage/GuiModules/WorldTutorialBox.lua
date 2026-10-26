local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TutorialBox = require(ReplicatedStorage.GuiModules.TutorialBox)

local CORNER_SIGNS = {
	Vector3.new(-1, -1, -1),
	Vector3.new(-1, -1, 1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(1, -1, 1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, 1, 1)
}

local BOX_EDGES = {
	{ 1, 2 }, { 1, 3 }, { 1, 5 },
	{ 2, 4 }, { 2, 6 },
	{ 3, 4 }, { 3, 7 },
	{ 4, 8 },
	{ 5, 6 }, { 5, 7 },
	{ 6, 8 },
	{ 7, 8 }
}

local SIZE_MULTIPLIER = 0.85
local nextRenderId = 0

local WorldTutorialBox = {}
WorldTutorialBox.__index = WorldTutorialBox

local function getViewportBounds(camera: Camera, boundsCFrame: CFrame, boundsSize: Vector3)
	local halfSize = boundsSize / 2
	local nearDepth = -camera.NearPlaneZ + 0.001
	local corners = {}
	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge

	local function include(point: Vector3)
		minX = math.min(minX, point.X)
		minY = math.min(minY, point.Y)
		maxX = math.max(maxX, point.X)
		maxY = math.max(maxY, point.Y)
	end

	for index, sign in ipairs(CORNER_SIGNS) do
		local worldPoint = boundsCFrame:PointToWorldSpace(Vector3.new(
			halfSize.X * sign.X,
			halfSize.Y * sign.Y,
			halfSize.Z * sign.Z
		))
		local viewportPoint = camera:WorldToViewportPoint(worldPoint)
		corners[index] = { World = worldPoint, Viewport = viewportPoint }

		if viewportPoint.Z >= nearDepth then
			include(viewportPoint)
		end
	end

	-- Keep the near-plane intersections when part of the bounds is behind the camera.
	for _, edge in ipairs(BOX_EDGES) do
		local first = corners[edge[1]]
		local second = corners[edge[2]]
		local firstDepth = first.Viewport.Z
		local secondDepth = second.Viewport.Z
		if (firstDepth >= nearDepth) ~= (secondDepth >= nearDepth) then
			local alpha = (nearDepth - firstDepth) / (secondDepth - firstDepth)
			local worldPoint = first.World:Lerp(second.World, alpha)
			include(camera:WorldToViewportPoint(worldPoint))
		end
	end

	if minX == math.huge then
		return
	end

	return minX, minY, maxX, maxY
end

local function getInitialSquareSide(camera: Camera, boundsCFrame: CFrame, boundsSize: Vector3, viewportSize: Vector2)
	local maxSide = math.max(viewportSize.X, viewportSize.Y)
	local radius = boundsSize.Magnitude / 2
	local distance = (boundsCFrame.Position - camera.CFrame.Position).Magnitude
	if distance <= radius then
		return maxSide
	end

	-- Use the bounds to choose a base size; camera distance changes are applied below.
	local unitPoint = camera.CFrame:PointToWorldSpace(Vector3.new(1, 0, -1))
	local unitProjection = camera:WorldToViewportPoint(unitPoint)
	local focalPixels = math.abs(unitProjection.X - viewportSize.X / 2)
	return math.min(maxSide, 2 * focalPixels * radius / math.sqrt(distance * distance - radius * radius))
end

function WorldTutorialBox.new(target: Model | BasePart, parent: Instance?)
	assert(target and (target:IsA("Model") or target:IsA("BasePart")), "WorldTutorialBox requires a Model or BasePart")

	local self = setmetatable({}, WorldTutorialBox)
	self._Target = target
	self._Visible = true
	self._Side = nil
	self._InitialModelDistance = nil
	self._TutorialBox = TutorialBox.new(parent)
	self._Box = self._TutorialBox:GetObject()

	nextRenderId += 1
	self._RenderStepName = "WorldTutorialBox_" .. nextRenderId
	RunService:BindToRenderStep(self._RenderStepName, Enum.RenderPriority.Camera.Value + 1, function()
		self:_Update()
	end)

	self:_Update()
	return self
end

function WorldTutorialBox:_Update()
	local target = self._Target
	local camera = Workspace.CurrentCamera
	if not self._Visible or not target:IsDescendantOf(Workspace) or not camera then
		self._TutorialBox:Hide()
		return
	end

	local boundsCFrame, boundsSize
	if target:IsA("Model") then
		boundsCFrame, boundsSize = target:GetBoundingBox()
	else
		boundsCFrame, boundsSize = target.CFrame, target.Size
	end

	if boundsSize.X <= 0 or boundsSize.Y <= 0 or boundsSize.Z <= 0 then
		self._TutorialBox:Hide()
		return
	end

	local minX, minY, maxX, maxY = getViewportBounds(camera, boundsCFrame, boundsSize)
	if not minX then
		self._TutorialBox:Hide()
		return
	end

	local viewportSize = camera.ViewportSize
	local left = math.clamp(minX, 0, viewportSize.X)
	local top = math.clamp(minY, 0, viewportSize.Y)
	local right = math.clamp(maxX, 0, viewportSize.X)
	local bottom = math.clamp(maxY, 0, viewportSize.Y)
	if right <= left or bottom <= top then
		self._TutorialBox:Hide()
		return
	end

	local centerPoint = camera:WorldToViewportPoint(boundsCFrame.Position)
	local centerX, centerY = centerPoint.X, centerPoint.Y
	if centerPoint.Z < -camera.NearPlaneZ + 0.001 then
		centerX = (left + right) / 2
		centerY = (top + bottom) / 2
	end

	local modelDistance = math.max((camera.CFrame.Position - boundsCFrame.Position).Magnitude, 0.1)
	if not self._Side then
		self._Side = getInitialSquareSide(camera, boundsCFrame, boundsSize, viewportSize)
		self._InitialModelDistance = modelDistance
	end
	local side = math.min(
		math.max(viewportSize.X, viewportSize.Y),
		self._Side * self._InitialModelDistance / modelDistance
	) * SIZE_MULTIPLIER
	local parent = self._Box.Parent
	local parentOrigin = Vector2.zero
	if parent:IsA("GuiObject") then
		parentOrigin = parent.AbsolutePosition + GuiService:GetGuiInset()
	elseif parent:IsA("ScreenGui") and not parent.IgnoreGuiInset then
		parentOrigin = GuiService:GetGuiInset()
	end

	local anchorPoint = self._Box.AnchorPoint
	self._Box.Position = UDim2.fromOffset(
		centerX - parentOrigin.X + side * (anchorPoint.X - 0.5),
		centerY - parentOrigin.Y + side * (anchorPoint.Y - 0.5)
	)
	self._Box.Size = UDim2.fromOffset(side, side)
	self._TutorialBox:Show()
end

function WorldTutorialBox:GetObject(): GuiObject
	return self._Box
end

function WorldTutorialBox:SetTarget(target: Model | BasePart)
	assert(target and (target:IsA("Model") or target:IsA("BasePart")), "WorldTutorialBox requires a Model or BasePart")
	self._Target = target
	self._Side = nil
	self._InitialModelDistance = nil
	self:_Update()
end

function WorldTutorialBox:SetVisible(visible: boolean)
	self._Visible = visible
	self:_Update()
end

function WorldTutorialBox:Show()
	self:SetVisible(true)
end

function WorldTutorialBox:Hide()
	self:SetVisible(false)
end

function WorldTutorialBox:Destroy()
	if not self._TutorialBox then
		return
	end

	RunService:UnbindFromRenderStep(self._RenderStepName)
	self._TutorialBox:Destroy()
	self._TutorialBox = nil
	self._Box = nil
	self._Target = nil
end

return WorldTutorialBox
