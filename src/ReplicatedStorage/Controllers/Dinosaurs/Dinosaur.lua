local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local ClientAssets = Assets:WaitForChild("ClientAssets")
local IncomeGui = ClientAssets:WaitForChild("IncomeGui")
local External = ReplicatedStorage:WaitForChild("External")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Trove = require(External:WaitForChild("Trove"))
local DinosaurUtils = require(Utils:WaitForChild("DinosaurUtils"))
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local BigNumbers = require(External:WaitForChild("BigNumbers"))
local Sigal = require(External:WaitForChild("Signal"))

local Dinosaur = {}
Dinosaur.__index = Dinosaur

local TURN_DURATION = 0.25

function Dinosaur.new(replicationData)
	local self = setmetatable({}, Dinosaur)

	self._Trove = Trove.new()

	self.Touched = Sigal.new()
	self._Trove:Add(self.Touched)

	self._Guid = replicationData.Guid
	self._OwnerUserId = replicationData.OwnerUserId
	self._Owner = Players:GetPlayerByUserId(self._OwnerUserId)
	self._DinosaurId = replicationData.DinosaurId
	self._Scale = replicationData.Scale
	self._Income = 0

	self:Update(replicationData)

	return self
end

function Dinosaur:GetOwnerUserId()
	return self._OwnerUserId
end

function Dinosaur:GetPlot()
	return self._Plot
end

function Dinosaur:GetGuid()
	return self._Guid
end

function Dinosaur:Update(replicationData)
	self._StartCFrame = replicationData.StartCFrame
	self._TargetCFrame = replicationData.TargetCFrame
	self._MoveStartTime = replicationData.MoveStartTime
	self._MoveDuration = replicationData.MoveDuration

	self:_UpdateDisplay()
end

function Dinosaur:FireEvent(eventName, ...)
	if eventName == "MoveTo" then
		self:_MoveTo(...)
	end
end

function Dinosaur:_LoadAnimations()
	local model = self._Model
	local animator = model:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		local animationController = model:FindFirstChildWhichIsA("AnimationController", true)
			or model:FindFirstChildWhichIsA("Humanoid", true)
		if not animationController then
			animationController = Instance.new("AnimationController")
			animationController.Parent = model
		end

		animator = Instance.new("Animator")
		animator.Parent = animationController
	end

	local idleAnimation = model:FindFirstChild("Idle")
	if idleAnimation and idleAnimation:IsA("Animation") then
		self._IdleTrack = animator:LoadAnimation(idleAnimation)
		self._IdleTrack.Looped = true
		self._IdleTrack.Priority = Enum.AnimationPriority.Idle
	end

	local walkAnimation = model:FindFirstChild("Walk")
	if walkAnimation and walkAnimation:IsA("Animation") then
		self._WalkTrack = animator:LoadAnimation(walkAnimation)
		self._WalkTrack.Looped = true
		self._WalkTrack.Priority = Enum.AnimationPriority.Movement
	end
end

function Dinosaur:Show(plot, parent)
	if self._Model and self._Plot == plot then
		return
	end
	self:Hide()

	local model = DinosaurUtils.CreateModel(self._DinosaurId, self._Scale)
	if not model then
		return
	end

	local root = model:FindFirstChild("HumanoidRootPart", true)
		or model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		model:Destroy()
		return
	end
	model.PrimaryPart = root

	self._ModelTrove = Trove.new()
	self._Trove:Add(self._ModelTrove)

	self._Plot = plot
	self._Model = model
	self._Walking = nil

	local groundCFrame = self:_GetGroundCFrame()
	DinosaurUtils.PositionAtGround(model, groundCFrame)
	self._PivotOffset = groundCFrame:ToObjectSpace(model:GetPivot())

	-- Keep the rig's root fixed while its joints animate the remaining parts.
	UtilFunctions.AnchorAllDescendants(model)
	model.PrimaryPart.Anchored = true

	model.Name = self._DinosaurId .. "_" .. self._Guid
	model.Parent = parent
	self._ModelTrove:Add(model)

	if self._Owner == Player then
		self:_SetupHitbox()
		self:_SetupIncomeGui()
	end

	self:_LoadAnimations()
	self:_UpdateDisplay()
	self._ModelTrove:Add(RunService.Heartbeat:Connect(function()
		self:_UpdateDisplay()
	end))
end

function Dinosaur:Hide()
	if self._IdleTrack then
		self._IdleTrack:Stop()
	end
	if self._WalkTrack then
		self._WalkTrack:Stop()
	end

	if self._ModelTrove then
		self._Trove:Remove(self._ModelTrove)
	end
	self._ModelTrove = nil
	self._Model = nil
	self._Plot = nil
	self._PivotOffset = nil
	self._IdleTrack = nil
	self._WalkTrack = nil
	self._Walking = nil
end

function Dinosaur:_SetWalking(walking)
	if self._Walking == walking then
		return
	end
	self._Walking = walking

	if walking then
		if self._IdleTrack then
			self._IdleTrack:Stop(0.2)
		end
		if self._WalkTrack then
			self._WalkTrack:Play(0.2)
		end
	else
		if self._WalkTrack then
			self._WalkTrack:Stop(0.2)
		end
		if self._IdleTrack then
			self._IdleTrack:Play(0.2)
		end
	end
end

function Dinosaur:_UpdateDisplay()
	if not self._Model then
		return
	end

	local groundCFrame, walking = self:_GetGroundCFrame()
	self._Model:PivotTo(groundCFrame * self._PivotOffset)
	self:_SetWalking(walking)
end

function Dinosaur:_GetGroundCFrame()
	local startCFrame = self._StartCFrame
	local targetCFrame = self._TargetCFrame
	local duration = self._MoveDuration
	local elapsed = Workspace:GetServerTimeNow() - self._MoveStartTime

	if duration > 0 and elapsed >= 0 and elapsed < duration then
		local alpha = math.clamp(elapsed / duration, 0, 1)
		local position = startCFrame.Position:Lerp(targetCFrame.Position, alpha)
		local direction = targetCFrame.Position - startCFrame.Position
		local walkingRotation = CFrame.lookAt(position, position + direction, startCFrame.UpVector).Rotation
		local turnAlpha = math.clamp(elapsed / math.min(TURN_DURATION, duration), 0, 1)
		local rotation = startCFrame.Rotation:Lerp(walkingRotation, turnAlpha)
		return CFrame.new(position) * rotation, true
	end

	return targetCFrame, false
end

function Dinosaur:_MoveTo(startCFrame, targetCFrame, moveStartTime, moveDuration)
	if moveStartTime < self._MoveStartTime then
		return
	end

	self._StartCFrame = startCFrame
	self._TargetCFrame = targetCFrame
	self._MoveStartTime = moveStartTime
	self._MoveDuration = moveDuration

	self:_UpdateDisplay()
end

function Dinosaur:_SetupHitbox()
	if not self._Model then return end

	local cframe, size = self._Model:GetBoundingBox()

	local newPart = Instance.new("Part")
	newPart.Size = size
	newPart.CFrame = cframe
	newPart.Transparency = 1
	newPart.CanCollide = false
	newPart.CanQuery = false
	newPart.CanTouch = true
	newPart.Massless = true
	newPart.Anchored = false
	newPart.Name = "_Hitbox"
	newPart.Parent = self._Model

	newPart.Touched:Connect(function(hitPart)
		local character = hitPart.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if player ~= Player then return end

		self.Touched:Fire()
	end)

	local newWeld = Instance.new("WeldConstraint")
	newWeld.Part0 = newPart
	newWeld.Part1 = self._Model.PrimaryPart
	newWeld.Parent = newPart

	self._ModelTrove:Add(newPart)
end

function Dinosaur:GetIncome()
	return self._Income
end

function Dinosaur:SetIncome(income : number)
	self._Income = income

	self:_UpdateIncomeGui()
end

function Dinosaur:_SetupIncomeGui()
	if not self._Model then return end

	local newIncomeGui = IncomeGui:Clone()
	newIncomeGui.Adornee = self._Model.PrimaryPart
	newIncomeGui.Parent = Player:WaitForChild("PlayerGui")
	self._IncomeGui = newIncomeGui
	self._ModelTrove:Add(self._IncomeGui)
	self._ModelTrove:Add(function()
		self._IncomeGui = nil
	end)

	self:_UpdateIncomeGui()
end

function Dinosaur:_UpdateIncomeGui()
	if not self._IncomeGui then return end

	self._IncomeGui.AmountText.Text = string.format("$%s", BigNumbers.GetNumberDisplay(self._Income))
end

function Dinosaur:Destroy()
	self:Hide()

	self._Trove:Clean()
end

return Dinosaur
