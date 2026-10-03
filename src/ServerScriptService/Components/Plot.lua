local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local FencePiece = Assets:WaitForChild("FencePiece") :: Model
local FenceEnd = Assets:WaitForChild("FenceEnd") :: Model
local External = ReplicatedStorage:WaitForChild("External")
local Component = require(External:WaitForChild("Component"))
local Trove = require(External:WaitForChild("Trove"))

local Plot = Component.new({
	Tag = "Plot",
	Ancestors = { Workspace }
})

function Plot:Construct()
	self.Instance = self.Instance :: Model

	self._Trove = Trove.new()

	self._Owner = nil :: Player?

	self:SetLevel(1)
end

function Plot:GetOwner() : Player?
	return self._Owner
end

function Plot:SetOwner(player : Player?)
	if self._Owner and (not player) then
		self._Owner = nil
		self:_CleanOwner()
	elseif (not self._Owner) and player then
		self._Owner = player
		self:_BuildOwner()
	end
end

function Plot:_BuildOwner()
	if not self._Owner then return end

	self._OwnerTrove = Trove.new()
	self._Trove:Add(self._OwnerTrove)

	self.Instance:SetAttribute("Owner", self._Owner.UserId)
	self._OwnerTrove:Add(function()
		self.Instance:SetAttribute("Owner", nil)
	end)

	self._OwnerTrove:Connect(self._Owner.CharacterAdded, function(character)
		self:_TeleportCharacter(character)
	end)

	if self._Owner.Character then
		self:_TeleportCharacter(self._Owner.Character)
	end
end

function Plot:_TeleportCharacter(character)
	local spawnPart : Part = self.Instance:FindFirstChild("_Spawn")
	if not spawnPart then
		error("No spawn part?")
		return
	end

	local pivot = character:GetPivot()
	local boundingCFrame, boundingSize = character:GetBoundingBox()
	local bottomY = boundingCFrame.Position.Y - (boundingSize.Y / 2)
	local pivotToFeetOffset = pivot.Position.Y - bottomY

	character:PivotTo(spawnPart.CFrame * CFrame.new(0, pivotToFeetOffset, 0))
end

function Plot:SetLevel(level : number)
	if level == self._Level then return end

	self._Level = level
	self.Instance:SetAttribute("Level", self._Level)

	self:_UpdateFence()
end

function Plot:_UpdateFence()
	local level = self._Level
	local extraFencingNeeded = level - 1
	local _, pieceSize = FencePiece:GetBoundingBox()

	if not self._Fencing then
		self._Fencing = {}
	end

	local fence1 = self.Instance.Fence.Fence1 :: Model
	local fence2 = self.Instance.Fence.Fence2 :: Model

	local _, fence1Size = fence1:GetBoundingBox()
	local fence1CFrame = fence1:GetPivot()
	local fence2CFrame = fence2:GetPivot()

	local function updateFence(fenceModel : Model)
		local fences = self._Fencing[fenceModel]
		if not fences then
			self._Fencing[fenceModel] = {}
			fences = self._Fencing[fenceModel]
		end

		local cframe, size = fenceModel:GetBoundingBox()

		-- Place new fencing
		for i = 1, extraFencingNeeded do
			if fences[i] then continue end

			local newFencePiece = FencePiece:Clone()

			local zDistance = pieceSize.Z * (i - 1)

			newFencePiece:PivotTo(cframe * CFrame.new(0, 0, (size.Z / 2) + (pieceSize.Z / 2) + zDistance))
			newFencePiece.Parent = self.Instance.Fence

			fences[i] = newFencePiece
		end

		-- Remove fencing no longer needed
		local fencesToRemove = {}
		for fenceIndex in pairs(fences) do
			if fenceIndex <= extraFencingNeeded then continue end
			table.insert(fencesToRemove, fenceIndex)
		end
		for _, fenceIndex in pairs(fencesToRemove) do
			local fencePiece = fences[fenceIndex]
			fencePiece:Destroy()
			fences[fenceIndex] = nil
		end
	end

	local function updateFenceEnd()
		local currentFenceEnd = self.Instance.Fence:FindFirstChild("FenceEnd")
		if currentFenceEnd then currentFenceEnd:Destroy() end

		local middleCFrame = CFrame.new((fence1CFrame.Position + fence2CFrame.Position) / 2) * fence1CFrame.Rotation

		local newFenceEnd = FenceEnd:Clone()
		local _, endSize = newFenceEnd:GetBoundingBox()
		local zOffset = (fence1Size.Z / 2) + (endSize.Z / 2) + (extraFencingNeeded * pieceSize.Z)

		newFenceEnd:PivotTo(middleCFrame * CFrame.new(0, 0, zOffset))
		newFenceEnd.Parent = self.Instance.Fence
	end

	local function adjustFloorPart()
		local floor : BasePart = self.Instance:FindFirstChild("_Floor")
		if not floor then return end

		local currentCFrame = floor.CFrame
		local zSize = fence1Size.Z + (extraFencingNeeded * pieceSize.Z)

		local oldSize = floor.Size
		floor.Size = Vector3.new(oldSize.X, oldSize.Y, zSize)

		local newSize = floor.Size

		-- When you increase a size along an axis,
		-- the center for that axis moves half the increase
		floor.CFrame = currentCFrame * CFrame.new(0, 0, (newSize.Z - oldSize.Z) / 2)
	end

	updateFence(fence1)
	updateFence(fence2)
	updateFenceEnd()
	adjustFloorPart()
end

function Plot:_CleanOwner()
	self:SetLevel(1)
	self._Trove:Remove(self._OwnerTrove)
	self._OwnerTrove = nil
end

function Plot:Stop()
	self._Trove:Clean()
end

return Plot
