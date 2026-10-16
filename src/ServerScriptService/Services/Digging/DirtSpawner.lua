local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local StageOneModel = Assets:WaitForChild("Dirt"):WaitForChild("1")
local RarityUtils = require(Utils:WaitForChild("RarityUtils"))
local Dirt = require(script.Parent:WaitForChild("Dirt"))

local DirtSpawner = {}
DirtSpawner.__index = DirtSpawner

local function getStageOneRadius()
	local boundingCFrame, boundingSize = StageOneModel:GetBoundingBox()
	local relativeBounds = StageOneModel:GetPivot():ToObjectSpace(boundingCFrame)
	local halfSize = boundingSize / 2
	local radius = 0

	for _, x in ipairs({ -halfSize.X, halfSize.X }) do
		for _, y in ipairs({ -halfSize.Y, halfSize.Y }) do
			for _, z in ipairs({ -halfSize.Z, halfSize.Z }) do
				local corner = relativeBounds:PointToWorldSpace(Vector3.new(x, y, z))
				radius = math.max(radius, Vector2.new(corner.X, corner.Z).Magnitude)
			end
		end
	end

	return radius
end

function DirtSpawner.new(instance, replicationService, config, lifecycleService)
	assert(instance:IsA("BasePart"), "DirtSpawner must be a BasePart")

	local self = setmetatable({}, DirtSpawner)
	self.Instance = instance
	self._Config = config
	self._ReplicationService = replicationService
	self._LifecycleService = lifecycleService
	self._Dirts = {}
	self._DirtCount = 0
	self._Random = Random.new()
	self._DirtRadius = getStageOneRadius()

	local initialDirt = math.min(self:_GetMaxDirt(), math.max(0, math.floor(config.InitialDirt)))
	for _ = 1, initialDirt do
		self:SpawnDirt()
	end

	self._SpawnThread = task.spawn(function()
		while not self._Destroyed do
			task.wait(self:_GetSpawnCooldown())
			self:SpawnDirt()
		end
	end)

	return self
end

function DirtSpawner:_GetMaxDirt()
	return math.max(0, math.floor(self._Config.MaxDirt))
end

function DirtSpawner:_GetSpawnCooldown()
	return math.max(0.1, self._Config.SpawnCooldown)
end

function DirtSpawner:_GetSpawnCFrame(scale)
	local size = self.Instance.Size
	local radius = self._DirtRadius * scale
	local xLimit = size.X / 2 - radius
	local zLimit = size.Z / 2 - radius
	if xLimit < 0 or zLimit < 0 then
		return
	end

	local x = self._Random:NextNumber(-xLimit, xLimit)
	local z = self._Random:NextNumber(-zLimit, zLimit)
	local angle = self._Random:NextNumber(0, math.pi * 2)

	return self.Instance.CFrame
		* CFrame.new(x, size.Y / 2, z)
		* CFrame.Angles(0, angle, 0)
end

function DirtSpawner:_GetSpacedSpawnCFrame(scale)
	local bestCFrame
	local bestClearanceSquared = -1
	local _, boundsSize = StageOneModel:GetBoundingBox()

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude

	local toExclude = {}
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(toExclude, player.Character)
		end
	end

	overlapParams.FilterDescendantsInstances = toExclude

	local boxSize = boundsSize * scale

	for _ = 1, 100 do
		local candidate = self:_GetSpawnCFrame(scale)
		if not candidate then
			return
		end

		local boxCFrame = candidate * CFrame.new(0, boxSize.Y / 2, 0) * CFrame.new(0, 0.01, 0)
		local hasObstacle = false
		for _, part in ipairs(Workspace:GetPartBoundsInBox(boxCFrame, boundsSize * scale, overlapParams)) do
			if part ~= self.Instance then
				hasObstacle = true
				break
			end
		end
		if hasObstacle then
			continue
		end

		local candidatePosition = candidate.Position
		local closestDistanceSquared = math.huge

		for _, otherDirt in pairs(self._Dirts) do
			local otherPosition = otherDirt:GetCFrame().Position
			local minCenterDistance = self._DirtRadius * (scale + otherDirt:GetScale()) + 3
			local x = candidatePosition.X - otherPosition.X
			local z = candidatePosition.Z - otherPosition.Z
			local distanceSquared = x * x + z * z
			closestDistanceSquared = math.min(closestDistanceSquared, distanceSquared / (minCenterDistance * minCenterDistance))
		end

		if closestDistanceSquared >= 1 then
			return candidate
		end

		if closestDistanceSquared > bestClearanceSquared then
			bestCFrame = candidate
			bestClearanceSquared = closestDistanceSquared
		end
	end

	return bestCFrame
end

function DirtSpawner:SpawnDirt()
	if self._Destroyed or not self.Instance:IsDescendantOf(Workspace) or self._DirtCount >= self:_GetMaxDirt() then
		return
	end

	local scaleRange = RarityUtils.GetLootTableResults(self._Config.ScaleLootTable)
	local scale = self._Random:NextNumber(scaleRange.MinScale, scaleRange.MaxScale)
	local spawnCFrame = self:_GetSpacedSpawnCFrame(scale)
	if not spawnCFrame then
		return
	end

	local dirtId = RarityUtils.GetLootTableResults(self._Config.DirtLootTable).Id
	local dirt = Dirt.new(self._ReplicationService, spawnCFrame, dirtId, scale, self._Config.Zone, self._Config.HealthMultiplier)
	local guid = dirt:GetGuid()

	self._Dirts[guid] = dirt
	self._DirtCount += 1

	dirt.DestroyedSignal:Connect(function()
		if self._Dirts[guid] then
			self._Dirts[guid] = nil
			self._DirtCount -= 1
		end
	end)

	dirt:ReplicateTo(self._LifecycleService:GetInitializedPlayers())

	return dirt
end

function DirtSpawner:ReplicateToPlayer(player, initialGuids)
	for _, dirt in pairs(self._Dirts) do
		table.insert(initialGuids, dirt:GetGuid())
		dirt:ReplicateTo({ player })
	end
end

function DirtSpawner:GetDirt(guid)
	return self._Dirts[guid]
end

function DirtSpawner:Destroy()
	if self._Destroyed then
		return
	end

	self._Destroyed = true
	task.cancel(self._SpawnThread)

	for _, dirt in pairs(self._Dirts) do
		dirt:Destroy()
	end

	self._Dirts = {}
	self._DirtCount = 0
end

return DirtSpawner
