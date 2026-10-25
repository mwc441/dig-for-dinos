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

function MutationUtils.Apply(model: Model, mutation: string, isViewport: boolean)
	local mutationPart = mutation and MutationParticles:FindFirstChild(mutation)
	if not mutationPart or not mutationPart:IsA("BasePart") then return end

	local mutationChildren = mutationPart:GetChildren()

	for _, basePart : BasePart in model:QueryDescendants("> BasePart") do
		if not basePart:IsA("BasePart") then continue end
		if basePart.Transparency >= 1 then continue end

		basePart.Transparency = mutationPart.Transparency
		basePart.Color = mutationPart.Color
		basePart.Material = mutationPart.Material
		basePart.MaterialVariant = mutationPart.MaterialVariant

		local sizeScale = basePart.Size.Magnitude / mutationPart.Size.Magnitude
		for _, child in mutationChildren do
			if child:IsA("ParticleEmitter") and isViewport then continue end
			if child:IsA("Highlight") then continue end

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
