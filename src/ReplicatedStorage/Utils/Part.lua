local Part = {}
Part.__index = Part

function Part.new(partInstance)
	local self = {}
	setmetatable(self, Part)

	if not partInstance:IsA("BasePart") then
		error("Needs a base part")
	end

	self._Instance = partInstance

	return self
end

function Part:IsPlayerWithinRange(player, radius)
	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	return self:IsWithinRange(rootPart.CFrame.Position, radius)
end

function Part:IsWithinRange(position, radius)
	local distance = (self._Instance.CFrame.Position - position).Magnitude

	return distance <= radius
end

function Part:IsInsidePartArea(cframe, y)
	y = y or 100

	local insideCFrame = self._Instance.CFrame:ToObjectSpace(cframe)
	local position = insideCFrame.Position
	local sizeX = self._Instance.Size.X / 2
	local sizeZ = self._Instance.Size.Z / 2

	if (position.X < sizeX) and (position.X > (-sizeX)) and (position.Z < sizeZ) and (position.Z > (-sizeZ)) and (position.Y < y) and (position.Y > -y) then
		return true
	end
end

function Part:PlayerIsInsidePartArea(player, y)
	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	return self:IsInsidePartArea(rootPart.CFrame, y)
end

-- Returns a CFrame and a Size (Vector2) of the given surface.
--
-- The CFrame:
--   * is positioned at the center of the surface
--   * has an UpVector = the surface normal
--   * has a LookVector aligned with a part edge, and pointing generally upwards in world space.
function Part:GetWorldOrientedSurface(normalId)
	local cf = self._Instance.CFrame
	local rot = cf - cf.Position

	local nObject = Vector3.fromNormalId(normalId)
	local nWorld = rot * nObject

	-- get orthogonal vector by utilizing the order of NormalId enums
	-- i.e. Front.Value is 5 -> (5+1)%6 = 0 -> Right.Value
	local xWorld = rot * Vector3.fromNormalId((normalId.Value + 1) % 6)

	-- get other orthogonal vector
	local zWorld = nWorld:Cross(xWorld)

	-- make them both point "generally down"
	if xWorld.Y > 0 then xWorld = -xWorld end
	if zWorld.Y > 0 then zWorld = -zWorld end

	-- choose the one pointing "more down" one as the z axis for the surface
	if xWorld.Y < zWorld.Y then zWorld = xWorld end

	-- redefine x axis based on that
	xWorld = nWorld:Cross(zWorld)

	local surfaceRot = CFrame.fromMatrix(Vector3.new(), xWorld, nWorld, zWorld)

	-- get width of part in direction of x and y
	local sizeInWorldSpace = rot * self._Instance.Size
	local sizeInSurfaceSpace = surfaceRot:Inverse() * sizeInWorldSpace

	-- get position on surface
	local surfaceCFrame = surfaceRot + cf.Position + nWorld * math.abs(sizeInSurfaceSpace.Y) / 2

	return surfaceCFrame, Vector2.new(math.abs(sizeInSurfaceSpace.X), math.abs(sizeInSurfaceSpace.Z))
end

return Part