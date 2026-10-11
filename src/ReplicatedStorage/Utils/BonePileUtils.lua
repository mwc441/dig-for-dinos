local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Particles = Assets:WaitForChild("Particles")
local BonePileRarityParticles = Particles:WaitForChild("BonePileRarities")
local MutationsEnum = require(ReplicatedStorage:WaitForChild("Enums"):WaitForChild("Mutations"))
local DinosaurDef = require(ReplicatedStorage:WaitForChild("ReplicatedConfigs"):WaitForChild("DinosaurDef"))
local UtilFunctions = require(script.Parent:WaitForChild("UtilFunctions"))

local BonePileUtils = {}
local CARRY_DISTANCE = 1.25

function BonePileUtils.GetCarryCFrame(torso: BasePart): CFrame
	return torso.CFrame * CFrame.new(0, 0, -CARRY_DISTANCE)
end

function BonePileUtils.GetScale(scale)
	if typeof(scale) ~= "number" or scale <= 0 or scale ~= scale or scale == math.huge then
		return 1
	end

	return scale
end

function BonePileUtils.CreateModel(dinosaurId, scale, mutation) : Model?
	local dinosaurInfo = DinosaurDef.GetDinosaurInfo(dinosaurId)
	if not dinosaurInfo then
		warn("Unknown dinosaur for bone pile " .. tostring(dinosaurId))
		return
	end

	local bonePileModels = Assets:FindFirstChild("BonePiles")
	local template = bonePileModels and bonePileModels:FindFirstChild(dinosaurId)
	if not template or not template:IsA("Model") then
		warn("Missing bone pile model for dinosaur " .. dinosaurId)
		return
	end

	local model = template:Clone()
	local root = model.PrimaryPart
	if not root then
		warn("Bone pile model has no BasePart: " .. dinosaurId)
		model:Destroy()
		return
	end

	local rarityParticles = BonePileRarityParticles:FindFirstChild(dinosaurInfo.Rarity)
	if rarityParticles then
		local newRarityParticles = rarityParticles:Clone() :: BasePart
		newRarityParticles.Anchored = false
		newRarityParticles.CanCollide = false
		newRarityParticles.CanQuery = false
		newRarityParticles.CanTouch = false
		newRarityParticles.Transparency = 1
		newRarityParticles.CFrame = root.CFrame
		newRarityParticles.Name = "_RARITYPARTICLES"
		newRarityParticles.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = newRarityParticles
		weld.Part1 = root
		weld.Parent = newRarityParticles
	end

	scale = BonePileUtils.GetScale(scale)
	model:ScaleTo(scale)
	UtilFunctions.AnchorAllDescendants(model, false)
	UtilFunctions.CanCollideAllDescendants(model, false)
	UtilFunctions.CanTouchAllDescendants(model, false)
	UtilFunctions.MasslessAllDescendants(model, true)
	model:SetAttribute("DinosaurId", dinosaurId)
	model:SetAttribute("Rarity", dinosaurInfo.Rarity)
	model:SetAttribute("Scale", scale)
	model:SetAttribute("Mutation", mutation or MutationsEnum.Normal)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CollectionService:AddTag(model, "BonePile")

	return model
end

function BonePileUtils.CarryPileModel(pileModel : Model, character : Model)
	local upperTorso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	if not upperTorso then return end

	pileModel:PivotTo(BonePileUtils.GetCarryCFrame(upperTorso))
	UtilFunctions.AnchorAllDescendants(pileModel, false)

	local weld = Instance.new("WeldConstraint")
	weld.Name = "BonePileCarryWeld"
	weld.Part0 = upperTorso
	weld.Part1 = pileModel.PrimaryPart
	weld.Parent = pileModel.PrimaryPart

	return weld
end

return BonePileUtils
