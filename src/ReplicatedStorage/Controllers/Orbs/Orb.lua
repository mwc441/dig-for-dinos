local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local External = ReplicatedStorage:WaitForChild("External")
local ClientAssets = Assets:WaitForChild("ClientAssets")
local Sounds = Assets:WaitForChild("Sounds")
local OrbSounds = Sounds:WaitForChild("OrbSounds"):GetChildren()
local OrbPart = ClientAssets:WaitForChild("OrbPart")
local OrbGui = ClientAssets:WaitForChild("OrbGui")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Components = ReplicatedStorage:WaitForChild("Components")
local HoverComponent = require(Components.Hover)
local SpinComponent = require(Components.Spin)
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local Signal = require(External:WaitForChild("Signal"))
local Trove = require(External:WaitForChild("Trove"))
local BigNumbers = require(External:WaitForChild("BigNumbers"))

local OrbsModel = Instance.new("Model")
OrbsModel.Name = "_Orbs"
OrbsModel.Parent = Workspace

local OrbsHighlight = Instance.new("Highlight")
OrbsHighlight.FillTransparency = 1
OrbsHighlight.Parent = OrbsModel

local ALIGNMENT_SPEED = 50
local LANDING_RADIUS_MIN = 7
local LANDING_RADIUS_MAX = 14
local LANDING_SPEED = 25
local LANDING_ARC_HEIGHT = 12
local LANDING_RAY_HEIGHT = 15
local LANDING_RAY_DISTANCE = 250
local LANDING_ATTEMPTS = 10
local ALIGNMENT_ARC_HEIGHT = 6

local Orb = {}
Orb.__index = Orb

local function getQuadraticBezierPoint(startPosition, controlPosition, endPosition, alpha)
	local inverseAlpha = 1 - alpha

	return (inverseAlpha * inverseAlpha * startPosition) + (2 * inverseAlpha * alpha * controlPosition) + (alpha * alpha * endPosition)
end

local function getArcControlPoint(startPosition, endPosition, height)
	local midpoint = startPosition:Lerp(endPosition, 0.5)

	return midpoint + Vector3.new(0, height, 0)
end

local function isValidGroundRaycastResult(raycastResult)
	return raycastResult
		and raycastResult.Instance.CanCollide
		and (raycastResult.Instance.CollisionGroup == "Default")
end

function Orb.new(orbController, replicationData, cframe)
	local self = {}
	setmetatable(self, Orb)

	self._Trove = Trove.new()

	self.OrbClaimedSignal = Signal.new()
	self._Trove:Add(self.OrbClaimedSignal)

	self._Guid = replicationData.Guid
	self._CFrame =  cframe or replicationData.Metadata.CFrame
	self._Metadata = replicationData.Metadata
	self._Landed = false
	self._Aligned = false
	self._OrbController = orbController

	self:_CreateModel()

	return self
end

function Orb:GetModel()
	return self._Model
end

function Orb:IsAncestorOf(part)
	if not self._Model then
		return false
	end

	if (self._Model == part) or (self._Model:IsAncestorOf(part)) then
		return true
	end
end

function Orb:_CreateModel()
	local newOrbPart = OrbPart:Clone()
	newOrbPart.CFrame = self._CFrame
	newOrbPart.Transparency = 1
	newOrbPart.Anchored = true
	newOrbPart.Parent = OrbsModel

	self._Model = newOrbPart
	self._Trove:Add(newOrbPart)

	-- Add 3d models to the orb
	local alignImmediately = false
	local rewardType = self._Metadata.RewardType
	local reward = self._Metadata.Reward

	local newOrbGui = OrbGui:Clone()
	newOrbGui.AmountText.Text = BigNumbers.GetNumberDisplay(reward or 0)
	newOrbGui.Icon.Image = Constants.Icons[rewardType] or ""
	newOrbGui.Adornee = newOrbPart
	newOrbGui.Parent = newOrbPart

	alignImmediately = true

	local newRandom = Random.new()
	local raycastParams = RaycastParams.new()
	raycastParams.CollisionGroup = "Default"
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true
	raycastParams.RespectCanCollide = true

	local groundRaycastResult
	local excludedInstances = { newOrbPart }

	for _ = 1, LANDING_ATTEMPTS do
		local angle = newRandom:NextNumber(0, math.pi * 2)
		local radius = newRandom:NextNumber(LANDING_RADIUS_MIN, LANDING_RADIUS_MAX)
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local rayOrigin = self._CFrame.Position + offset + Vector3.new(0, LANDING_RAY_HEIGHT, 0)

		raycastParams.FilterDescendantsInstances = excludedInstances

		local raycastResult = Workspace:Raycast(rayOrigin, Vector3.new(0, -LANDING_RAY_DISTANCE, 0), raycastParams)

		if isValidGroundRaycastResult(raycastResult) then
			groundRaycastResult = raycastResult
			break
		elseif raycastResult then
			table.insert(excludedInstances, raycastResult.Instance)
		end
	end

	if not groundRaycastResult then
		local rayOrigin = self._CFrame.Position + Vector3.new(0, LANDING_RAY_HEIGHT, 0)

		raycastParams.FilterDescendantsInstances = excludedInstances

		local raycastResult = Workspace:Raycast(rayOrigin, Vector3.new(0, -LANDING_RAY_DISTANCE, 0), raycastParams)

		if isValidGroundRaycastResult(raycastResult) then
			groundRaycastResult = raycastResult
		end
	end

	local startCFrame = self._CFrame
	local endPosition = startCFrame.Position

	if groundRaycastResult then
		endPosition = groundRaycastResult.Position + Vector3.new(0, newOrbPart.Size.Y, 0)
	end

	local endCFrame = CFrame.new(endPosition) * startCFrame.Rotation
	local distance = (endPosition - startCFrame.Position).Magnitude
	local totalTime = math.max(distance / LANDING_SPEED, 0.2)
	local arcHeight = math.max(distance * 0.35, LANDING_ARC_HEIGHT)
	local controlPosition = getArcControlPoint(startCFrame.Position, endPosition, arcHeight)
	local total = 0

	local landingConnection
	landingConnection = RunService.Heartbeat:Connect(function(dt)
		total += dt

		local alpha = math.min(total / totalTime, 1)
		local bezierPosition = getQuadraticBezierPoint(startCFrame.Position, controlPosition, endPosition, alpha)

		newOrbPart.CFrame = CFrame.new(bezierPosition) * startCFrame.Rotation:Lerp(endCFrame.Rotation, alpha)

		if total >= totalTime then
			self._Trove:Remove(landingConnection)

			self._Model:SetAttribute("HoverDistance", newOrbPart.Size.Y / 3)
			self._Model:SetAttribute("HoverTime", 2)
			self._Model:SetAttribute("SpinSpeed", 20)
			CollectionService:AddTag(self._Model, "Hover")
			CollectionService:AddTag(self._Model, "Spin")
			SpinComponent:WaitForInstance(self._Model):await()
			HoverComponent:WaitForInstance(self._Model):await()

			if alignImmediately then
				self._Landed = true
				self:AlignPositionToCharacter()
			else
				task.delay(0.25, function()
					self._Landed = true
				end)
			end
		end
	end)
	self._Trove:Add(landingConnection)

	self._Trove:Add(newOrbPart.AncestryChanged:Connect(function()
		if not newOrbPart.Parent then
			self.OrbClaimedSignal:Fire(self._Guid)
			self:Destroy()
		end
	end))
end

function Orb:AlignPositionToCharacter()
	if not self._Landed then
		return
	end

	if self._Aligned then
		return
	end

	self._Aligned = true

	local character = Player.Character
	if not character then
		character = Player.CharacterAdded:Wait()
	end

	local rootPart = character:WaitForChild("HumanoidRootPart")

	CollectionService:RemoveTag(self._Model, "Hover")
	CollectionService:RemoveTag(self._Model, "Spin")

	local distance = (rootPart.CFrame.Position - self._Model.CFrame.Position).Magnitude

	local startCFrame = self._Model.CFrame
	local totalTime = math.max(distance / ALIGNMENT_SPEED, 0.1)
	local arcHeight = math.max(distance * 0.35, ALIGNMENT_ARC_HEIGHT)
	local total = 0

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		total += dt

		local alpha = math.min(total / totalTime, 1)
		local endCFrame = rootPart.CFrame
		local controlPosition = getArcControlPoint(startCFrame.Position, endCFrame.Position, arcHeight)
		local bezierPosition = getQuadraticBezierPoint(startCFrame.Position, controlPosition, endCFrame.Position, alpha)

		self._Model.CFrame = CFrame.new(bezierPosition) * startCFrame.Rotation:Lerp(endCFrame.Rotation, alpha)

		if total >= totalTime then
			self._Trove:Remove(connection)

			local randomSound = OrbSounds[math.random(1, #OrbSounds)]

			UtilFunctions.PlaySoundAtLocation(randomSound, rootPart.CFrame)

			self.OrbClaimedSignal:Fire(self._Guid)

			self:Destroy()
		end
	end)
	self._Trove:Add(connection)
end

function Orb:Destroy()
	self._Trove:Clean()
end

return Orb
