local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local MutationParticles = Assets:WaitForChild("Particles"):WaitForChild("Mutations")

local MutationUtils = {}

local function scaleEmitterSize(emitter: ParticleEmitter, scale: number)
	local keypoints = {}
	for index, keypoint in emitter.Size.Keypoints do
		keypoints[index] = NumberSequenceKeypoint.new(
			keypoint.Time,
			keypoint.Value * scale,
			keypoint.Envelope * scale
		)
	end
	emitter.Size = NumberSequence.new(keypoints)
end

function MutationUtils.Apply(model: Model, mutation: string, cloneParticles: boolean)
	local mutationPart = mutation and MutationParticles:FindFirstChild(mutation)
	if not mutationPart or not mutationPart:IsA("BasePart") then return end

	local mutationChildren = mutationPart:GetChildren()

	for _, basePart : BasePart in model:QueryDescendants("> BasePart") do
		if not basePart:IsA("BasePart") then continue end
		if basePart.Transparency >= 1 then continue end

		basePart.Color = mutationPart.Color
		basePart.Material = mutationPart.Material
		basePart.MaterialVariant = mutationPart.MaterialVariant

		local sizeScale = basePart.Size.Magnitude / mutationPart.Size.Magnitude
		for _, child in mutationChildren do
			if child:IsA("ParticleEmitter") and (not cloneParticles) then continue end

			local newChild = child:Clone()
			if newChild:IsA("ParticleEmitter") then
				scaleEmitterSize(newChild, sizeScale)
			end
			for _, descendant in newChild:GetDescendants() do
				if descendant:IsA("ParticleEmitter") then
					scaleEmitterSize(descendant, sizeScale)
				end
			end
			newChild.Parent = basePart
		end
	end
end

return MutationUtils
