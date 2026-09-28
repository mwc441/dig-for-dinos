local Workspace = game:GetService("Workspace")

local DEFAULT_MAX_HEIGHT = 256

local Zone = {}
Zone.__index = Zone

function Zone.new(nodesFolder)
	local self = {}
	setmetatable(self, Zone)

	self._Height = DEFAULT_MAX_HEIGHT

	self._Nodes = nodesFolder

	self:_CalculateMiddle()

	self:_CalculateFurthestPoint()

	self:_InitializeFaces()

	return self
end

function Zone:SetHeight(height)
	self._Height = height

	if self._FacesFolder then
		self._FacesFolder:Destroy()
	end

	self:_InitializeFaces()
end

function Zone:_CalculateMiddle()
	local total = Vector3.zero
	local totalNodes = 0
	for _, node in pairs(self._Nodes:GetChildren()) do
		if not node:IsA("BasePart") then
			continue
		end

		total += node.CFrame.Position
		totalNodes += 1
	end

	local middle = total / totalNodes

	self._Middle = middle
end

function Zone:_CalculateFurthestPoint()
	local furthestPoint = self._Middle
	local furthestDistance = 0
	for _, node in pairs(self._Nodes:GetChildren()) do
		if not node:IsA("BasePart") then
			continue
		end

		local distance = (node.CFrame.Position - self._Middle).Magnitude

		if distance > furthestDistance then
			furthestDistance = distance
			furthestPoint = node.CFrame.Position
		end
	end

	self._FurthestPoint = furthestPoint
	self._FurthestDistance = furthestDistance
end

function Zone:_InitializeFaces()
	local min = self._Nodes.Root.CFrame.Position.Y - (self._Height)

	local max = self._Nodes.Root.CFrame.Position.Y + self._Height

	local facesFolder = Instance.new("Folder")
	facesFolder.Name = "Faces"

	local cursor = self._Nodes.Root

	repeat
		local nextNode = cursor.Connection.Attachment1.Parent

		local here = cursor.Position
		local there = nextNode.Position
		local midpoint = (here + there) / 2
		local delta = (there - here) * Vector3.new(1, 0, 1)
		local length = delta.Magnitude

		local y = (min + max) / 2

		local position = Vector3.new(midpoint.X, y, midpoint.Z)
		local cframe = CFrame.new(position, position + delta)

		local face = Instance.new("Part")
		face.Anchored = true
		face.CanCollide = false
		face.Transparency = 1
		face.Color = Color3.new(1, 0.5, 0.5)
		face.CFrame = cframe
		face.Size = Vector3.new(0, max - min, length)
		face.Parent = facesFolder

		cursor = nextNode

	until cursor == self._Nodes.Root

	facesFolder.Parent = Workspace

	self._FacesFolder = facesFolder
end

function Zone:DoesContainPoint(point)
	local distance = (self._Middle - point).Magnitude
	if distance > self._FurthestDistance then
		return false
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = self._FacesFolder:GetChildren()

	-- point in polygon algorithm demands an infinite ray, so we just
	-- use one of arbitrary length in order to get a similar effect
	local direction = Vector3.new(8192, 0, 0)

	debug.profilebegin("Point Check")
	local intersectionCount = 0
	local result = workspace:Raycast(point, direction, params)
	while result do
		intersectionCount += 1

		local filteredDescendants = params.FilterDescendantsInstances

		local index = table.find(filteredDescendants, result.Instance)
		if index then
			table.remove(filteredDescendants, index)
		end

		params.FilterDescendantsInstances = filteredDescendants

		result = workspace:Raycast(point, direction, params)
	end
	debug.profileend()

	return (intersectionCount % 2) == 1
end

function Zone:Destroy()
	if self._FacesFolder then
		self._FacesFolder:Destroy()
	end
	self._FacesFolder = nil
end

return Zone