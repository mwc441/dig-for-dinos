local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local MutationParticles = Assets:WaitForChild("Particles"):WaitForChild("Mutations")

local MutationUtils = {}
local THIRD_NAMES = { "Front", "Middle", "Back" }

local function scaleEmitter(emitter: ParticleEmitter, scale: number)
	local keypoints = {}

	local particleScale = 1.1 * math.log(1 + scale)
	for index, keypoint in emitter.Size.Keypoints do
		keypoints[index] = NumberSequenceKeypoint.new(
			keypoint.Time,
			keypoint.Value * particleScale,
			keypoint.Envelope * particleScale
		)
	end
	emitter.Size = NumberSequence.new(keypoints)

	emitter.Rate *= particleScale
end

local function getParticleBoundsByThird(model: Model)
	local boundsCFrame, boundsSize = model:GetBoundingBox()
	-- Local -Z is the model's front; clip visible part bounds into three depth slices.
	local thirdDepth = boundsSize.Z / 3
	local halfDepth = boundsSize.Z / 2
	local thirds = {}
	local visibleParts = {}

	for index = 1, 3 do
		thirds[index] = {
			StartZ = -halfDepth + (index - 1) * thirdDepth,
			EndZ = -halfDepth + index * thirdDepth,
			MinX = math.huge,
			MinY = math.huge,
			MinZ = math.huge,
			MaxX = -math.huge,
			MaxY = -math.huge,
			MaxZ = -math.huge,
			Parts = {}
		}
	end

	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") or part.Transparency >= 1 then continue end
		table.insert(visibleParts, part)

		local localCFrame = boundsCFrame:ToObjectSpace(part.CFrame)
		local halfSize = part.Size / 2
		local right, up, look = localCFrame.RightVector, localCFrame.UpVector, localCFrame.LookVector
		local extent = Vector3.new(
			math.abs(right.X) * halfSize.X + math.abs(up.X) * halfSize.Y + math.abs(look.X) * halfSize.Z,
			math.abs(right.Y) * halfSize.X + math.abs(up.Y) * halfSize.Y + math.abs(look.Y) * halfSize.Z,
			math.abs(right.Z) * halfSize.X + math.abs(up.Z) * halfSize.Y + math.abs(look.Z) * halfSize.Z
		)
		local partMin = localCFrame.Position - extent
		local partMax = localCFrame.Position + extent

		for _, third in thirds do
			local minZ = math.max(partMin.Z, third.StartZ)
			local maxZ = math.min(partMax.Z, third.EndZ)
			if maxZ <= minZ then continue end

			third.MinX = math.min(third.MinX, partMin.X)
			third.MinY = math.min(third.MinY, partMin.Y)
			third.MinZ = math.min(third.MinZ, minZ)
			third.MaxX = math.max(third.MaxX, partMax.X)
			third.MaxY = math.max(third.MaxY, partMax.Y)
			third.MaxZ = math.max(third.MaxZ, maxZ)
			table.insert(third.Parts, part)
		end
	end

	local result = {}
	for index, third in thirds do
		local minX, minY, minZ = third.MinX, third.MinY, third.MinZ
		local maxX, maxY, maxZ = third.MaxX, third.MaxY, third.MaxZ
		if minX == math.huge then
			minX, minY, minZ = -boundsSize.X / 2, -boundsSize.Y / 2, third.StartZ
			maxX, maxY, maxZ = boundsSize.X / 2, boundsSize.Y / 2, third.EndZ
		end

		local centerCFrame = boundsCFrame * CFrame.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
		local nearestPart
		local nearestDistance = math.huge
		local candidates = if #third.Parts > 0 then third.Parts else visibleParts
		for _, part in candidates do
			local distance = (part.Position - centerCFrame.Position).Magnitude
			if distance < nearestDistance then
				nearestPart = part
				nearestDistance = distance
			end
		end

		result[index] = {
			CFrame = centerCFrame,
			Size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ),
			WeldPart = nearestPart
		}
	end

	return result
end

function MutationUtils.Apply(model: Model, mutation: string, isViewport: boolean)
	local mutationPart = mutation and MutationParticles:FindFirstChild(mutation)
	if not mutationPart or not mutationPart:IsA("BasePart") then return end

	local particleChildren = {}
	local partChildren = {}
	for _, child in mutationPart:GetChildren() do
		if child:IsA("Highlight") then continue end
		if child:IsA("ParticleEmitter") or child:FindFirstChildWhichIsA("ParticleEmitter", true) then
			if not isViewport then table.insert(particleChildren, child) end
		else
			table.insert(partChildren, child)
		end
	end
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	local thirdBounds = root and #particleChildren > 0 and getParticleBoundsByThird(model)

	for _, basePart : BasePart in model:QueryDescendants("> BasePart") do
		if not basePart:IsA("BasePart") then continue end
		if basePart.Transparency >= 1 then continue end

		basePart.Transparency = mutationPart.Transparency
		basePart.Color = mutationPart.Color
		basePart.Material = mutationPart.Material
		basePart.MaterialVariant = mutationPart.MaterialVariant

		for _, child in partChildren do
			local newChild = child:Clone()
			newChild.Parent = basePart
		end
	end

	if root and thirdBounds then
		for index, bounds in thirdBounds do
			local particlePart = Instance.new("Part")
			particlePart.Name = "_MutationParticles" .. THIRD_NAMES[index]
			particlePart.Size = bounds.Size
			particlePart.CFrame = bounds.CFrame
			particlePart.Transparency = 1
			particlePart.Anchored = false
			particlePart.CanCollide = false
			particlePart.CanQuery = false
			particlePart.CanTouch = false
			particlePart.CastShadow = false
			particlePart.Massless = true
			particlePart.Parent = model

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = particlePart
			weld.Part1 = bounds.WeldPart or root
			weld.Parent = particlePart

			local sizeScale = bounds.Size.Magnitude / mutationPart.Size.Magnitude
			for _, child in particleChildren do
				local newChild = child:Clone()
				if newChild:IsA("ParticleEmitter") then
					scaleEmitter(newChild, sizeScale)
				end
				for _, descendant in newChild:GetDescendants() do
					if descendant:IsA("ParticleEmitter") then
						scaleEmitter(descendant, sizeScale)
					end
				end
				newChild.Parent = particlePart
			end
		end
	end

	if not isViewport then
		local highlights = mutationPart:QueryDescendants("Highlight") :: { Highlight }
		for _, highlight in pairs(highlights) do
			local newHighlight = highlight:Clone()
			newHighlight.Adornee = model
			newHighlight.Parent = model
		end
	end
end

return MutationUtils
