local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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

function Plot:_CleanOwner()
	self._Trove:Remove(self._OwnerTrove)
	self._OwnerTrove = nil
end

function Plot:Stop()
	self._Trove:Clean()
end

return Plot
