local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MutationsEnum = require(ReplicatedStorage:WaitForChild("Enums"):WaitForChild("Mutations"))
local Replicator = require(ServerScriptService.Services.Replication.Replicator)

local WALK_SPEED = 8
local MIN_IDLE_TIME = 4
local MAX_IDLE_TIME = 9
local MIN_WALK_DISTANCE = 10
local SMALL_FLOOR_WALK_FRACTION = 0.4
local TARGET_SAMPLE_ATTEMPTS = 24

local Dinosaur = {}
Dinosaur.__index = Dinosaur
setmetatable(Dinosaur, Replicator)

function Dinosaur.new(replicationService, owner, floor, savedData, spawnCFrame)
	local self = Replicator.new(replicationService)
	setmetatable(self, Dinosaur)

	self._Guid = savedData.Guid
	self._Type = "Dinosaur"
	self._OwnerUserId = owner.UserId
	self._DinosaurId = savedData.Id
	self._Scale = savedData.Scale
	self._Mutation = savedData.Mutation or MutationsEnum.Normal
	self._Floor = floor
	self._Random = Random.new()
	self._WalkSpeed = WALK_SPEED
	self._Income = 0

	local groundCFrame = spawnCFrame or self:_GetRandomGroundCFrame()
	if not spawnCFrame then
		groundCFrame *= CFrame.Angles(0, self._Random:NextNumber(-math.pi, math.pi), 0)
	end

	self._StartCFrame = groundCFrame
	self._TargetCFrame = groundCFrame
	self._MoveStartTime = Workspace:GetServerTimeNow()
	self._MoveDuration = 0

	self:_ScheduleNextWalk()

	return self
end

function Dinosaur:GetReplicationData()
	local replicationData = Replicator.GetReplicationData(self)
	replicationData.OwnerUserId = self._OwnerUserId
	replicationData.DinosaurId = self._DinosaurId
	replicationData.Scale = self._Scale
	replicationData.Mutation = self._Mutation
	replicationData.StartCFrame = self._StartCFrame
	replicationData.TargetCFrame = self._TargetCFrame
	replicationData.MoveStartTime = self._MoveStartTime
	replicationData.MoveDuration = self._MoveDuration

	return replicationData
end

function Dinosaur:GetIncome()
	return self._Income
end

function Dinosaur:SetIncome(income : number)
	self._Income = income
end

function Dinosaur:AddToIncome(income : number)
	self._Income += income
end

function Dinosaur:_GetRandomGroundCFrame(startPosition, minimumDistance)
	local floor = self._Floor
	local floorSize = floor.Size
	local margin = math.min(4 * self._Scale, floorSize.X / 2, floorSize.Z / 2)
	local halfWalkableX = floorSize.X / 2 - margin
	local halfWalkableZ = floorSize.Z / 2 - margin

	for _ = 1, TARGET_SAMPLE_ATTEMPTS do
		local x = self._Random:NextNumber(-halfWalkableX, halfWalkableX)
		local z = self._Random:NextNumber(-halfWalkableZ, halfWalkableZ)
		local groundCFrame = floor.CFrame * CFrame.new(x, floorSize.Y / 2, z)
		if not startPosition or (groundCFrame.Position - startPosition).Magnitude >= minimumDistance then
			return groundCFrame
		end
	end

	local validCorners = {}
	local farthestCorner
	local farthestDistance = -1
	for _, x in ipairs({ -halfWalkableX, halfWalkableX }) do
		for _, z in ipairs({ -halfWalkableZ, halfWalkableZ }) do
			local corner = floor.CFrame * CFrame.new(x, floorSize.Y / 2, z)
			local distance = (corner.Position - startPosition).Magnitude
			if distance >= minimumDistance then
				table.insert(validCorners, corner)
			end
			if distance > farthestDistance then
				farthestCorner = corner
				farthestDistance = distance
			end
		end
	end

	if #validCorners > 0 then
		return validCorners[self._Random:NextInteger(1, #validCorners)]
	end
	return farthestCorner
end

function Dinosaur:_ScheduleNextWalk()
	local waitTime = self._MoveDuration + self._Random:NextNumber(MIN_IDLE_TIME, MAX_IDLE_TIME)
	self._WalkThread = task.delay(waitTime, function()
		self._WalkThread = nil
		self:_PickNewTarget()
	end)
end

function Dinosaur:_PickNewTarget()
	if self._Destroyed then
		return
	end

	local floor = self._Floor
	local startPosition = self._TargetCFrame.Position
	local minimumDistance = math.min(MIN_WALK_DISTANCE, math.max(floor.Size.X, floor.Size.Z) * SMALL_FLOOR_WALK_FRACTION)
	local targetPosition = self:_GetRandomGroundCFrame(startPosition, minimumDistance).Position
	local direction = targetPosition - startPosition

	self._StartCFrame = self._TargetCFrame
	self._MoveStartTime = Workspace:GetServerTimeNow()
	self._MoveDuration = direction.Magnitude > 0.01 and direction.Magnitude / self._WalkSpeed or 0

	if direction.Magnitude > 0.01 then
		self._TargetCFrame = CFrame.lookAt(targetPosition, targetPosition + direction, floor.CFrame.UpVector)
	else
		self._TargetCFrame = self._StartCFrame
	end

	self:FireEvent("MoveTo", self._StartCFrame, self._TargetCFrame, self._MoveStartTime, self._MoveDuration)
	self:_ScheduleNextWalk()
end

function Dinosaur:Destroy()
	if self._Destroyed then
		return
	end

	if self._WalkThread then
		task.cancel(self._WalkThread)
		self._WalkThread = nil
	end

	Replicator.Destroy(self)
end

return Dinosaur
