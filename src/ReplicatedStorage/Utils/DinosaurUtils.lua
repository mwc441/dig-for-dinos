local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Dinosaurs = Assets:WaitForChild("Dinosaurs")
local DinosaurDef = require(ReplicatedStorage:WaitForChild("ReplicatedConfigs"):WaitForChild("DinosaurDef"))
local BonePileUtils = require(script.Parent:WaitForChild("BonePileUtils"))
local UtilFunctions = require(script.Parent:WaitForChild("UtilFunctions"))

local DinosaurUtils = {}

function DinosaurUtils.CreateModel(dinosaurId, scale): Model?
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
	model:ScaleTo(scale)
	UtilFunctions.AnchorAllDescendants(model, true)
	UtilFunctions.CanCollideAllDescendants(model, false)
	UtilFunctions.CanQueryAllDescendants(model, false)
	UtilFunctions.CanTouchAllDescendants(model, false)
	model:SetAttribute("DinosaurId", dinosaurId)
	model:SetAttribute("Scale", scale)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	return model
end

function DinosaurUtils.PositionAtGround(model: Model, groundCFrame: CFrame)
	local _, boundsSize = model:GetBoundingBox()
	local targetBounds = groundCFrame * CFrame.new(0, boundsSize.Y / 2, 0)
	UtilFunctions.MoveModelByBoundingBox(model, targetBounds)
end

return DinosaurUtils
