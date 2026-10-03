local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local External = ReplicatedStorage:WaitForChild("External")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Animations = Assets:WaitForChild("Animations")
local ShovelIdleAnimation : Animation = Animations:WaitForChild("ShovelIdle")
local ShovelDigAnimation : Animation = Animations:WaitForChild("ShovelDig")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Trove = require(External:WaitForChild("Trove"))
local ItemDef = require(ReplicatedConfigs:WaitForChild("ItemDef"))
local Knit = require(External:WaitForChild("Knit"))
local Derpbar = require(ReplicatedStorage:WaitForChild("Derpbar"))
local Dirt = require(script.Parent:WaitForChild("Dirt"))

local DIG_BOX_WIDTH = 6
local DIG_BOX_VERTICAL_PADDING = 1
local DIG_RANGE = 8
local DirtFolder = Dirt.GetFolder()
local DirtOverlapParams = OverlapParams.new()
DirtOverlapParams.IncludeInstances = { DirtFolder }

local DigController = {
	Name = "DigController",
	_DigService = nil,
	_ReplicationController = nil,
	_Dirts = {},
	_InitialDirtGuids = nil,
	_ShovelTrove = Trove.new(),
	_LastDig = nil,
	_NextPredictionId = 0
}

function DigController:KnitStart()
	self._DigService = Knit.GetService("DigService")
	self._ReplicationController = require(ReplicatedStorage.Controllers.Replication.ReplicationController)
	self._DigService.InitialDirtGuids:Observe(function(initialGuids)
		if not initialGuids then return end

		self._InitialDirtGuids = {}
		for _, guid in ipairs(initialGuids) do
			self._InitialDirtGuids[guid] = true
		end

		for _, replicationData in pairs(self._ReplicationController:GetReplicatorsOfType("Dirt")) do
			self:_CreateDirt(replicationData)
		end
	end)

	self._ReplicationController.ReplicatorReplicatedSignal:Connect(function(replicationData)
		if replicationData.Type == "Dirt" then
			self:_CreateDirt(replicationData)
		end
	end)

	self._ReplicationController.ReplicatorUpdatedSignal:Connect(function(replicationData)
		if replicationData.Type == "Dirt" then
			self:_UpdateDirt(replicationData)
		end
	end)

	self._ReplicationController.ReplicatorDereplicatedSignal:Connect(function(guid)
		self:_DestroyDirt(guid)
	end)

	for _, replicationData in pairs(self._ReplicationController:GetReplicatorsOfType("Dirt")) do
		self:_CreateDirt(replicationData)
	end

	ContextActionService.LocalToolEquipped:Connect(function(tool)
		local itemId = tool:GetAttribute("ItemId")
		if type(itemId) ~= "string" then
			return
		end

		local itemInfo = ItemDef.GetItemInfo(itemId)
		if not itemInfo or itemInfo.Category ~= ItemDef.Categories.Shovel then
			return
		end

		self:SetupShovel(tool)
	end)
end

function DigController:_CreateDirt(replicationData)
	local guid = replicationData.Guid
	if not self._InitialDirtGuids then
		-- ReplicationController keeps this data until the startup GUID list arrives.
		return
	end

	if self._Dirts[guid] then
		self._Dirts[guid]:Update(replicationData)
		return
	end

	self._Dirts[guid] = Dirt.new(replicationData, not self._InitialDirtGuids[guid])
end

function DigController:_UpdateDirt(replicationData)
	local dirt = self._Dirts[replicationData.Guid]
	if dirt then
		dirt:Update(replicationData)
	else
		self:_CreateDirt(replicationData)
	end
end

function DigController:_DestroyDirt(guid)
	local dirt = self._Dirts[guid]
	if dirt then
		dirt:Destroy()
		self._Dirts[guid] = nil
	end
end

function DigController:_GetDigCooldown()
	return 1 -- TODO: Upgrades for this?
end

function DigController:_GetNearestDirtGuid()
	local character = Player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid then
		return
	end

	local position = rootPart.Position
	local lookVector = rootPart.CFrame.LookVector
	local forward = Vector3.new(lookVector.X, 0, lookVector.Z)
	if forward.Magnitude == 0 then
		return
	end
	forward = forward.Unit

	local range = DIG_RANGE
	local halfRootHeight = rootPart.Size.Y / 2
	local floorOffset = humanoid.HipHeight + halfRootHeight
	local bottomY = position.Y - floorOffset - DIG_BOX_VERTICAL_PADDING
	local topY = position.Y + halfRootHeight + DIG_BOX_VERTICAL_PADDING
	local boxCenter = Vector3.new(position.X, (bottomY + topY) / 2, position.Z) + forward * (range / 2)
	local boxCFrame = CFrame.lookAt(boxCenter, boxCenter + forward)
	local boxSize = Vector3.new(DIG_BOX_WIDTH, topY - bottomY, range)
	local nearestGuid
	local nearestDistanceSquared = math.huge

	for _, part in ipairs(Workspace:GetPartBoundsInBox(boxCFrame, boxSize, DirtOverlapParams)) do
		local model = part
		while model and model.Parent ~= DirtFolder do
			model = model.Parent
		end
		if not model then continue end

		local guid = model and model:GetAttribute("DirtGuid")
		local dirt = guid and self._Dirts[guid]
		if dirt and dirt:GetModel() == model then
			local dirtPosition = dirt:GetCFrame().Position
			local x = dirtPosition.X - position.X
			local z = dirtPosition.Z - position.Z
			local distanceSquared = x * x + z * z
			local dirtRange = DIG_RANGE * dirt:GetScale()

			if distanceSquared <= dirtRange ^ 2 and distanceSquared <= nearestDistanceSquared then
				nearestGuid = guid
				nearestDistanceSquared = distanceSquared
			end
		end
	end

	return nearestGuid
end

function DigController:SetupShovel(tool)
	self._ShovelTrove:Clean()
	self._ShovelTrove:Connect(tool.Unequipped, function()
		self._ShovelTrove:Clean()
	end)
	self._ShovelTrove:Add(function()
		if self._DigTrack then
			self._DigTrack:Stop(0.5)
			self._DigTrack = nil
		end
	end)

	local autoShovelConnect
	local inputChangedConnect
	local function disconnect()
		if autoShovelConnect then
			self._ShovelTrove:Remove(autoShovelConnect)
			autoShovelConnect = nil
		end

		if inputChangedConnect then
			self._ShovelTrove:Remove(inputChangedConnect)
			inputChangedConnect = nil
		end
	end

	self._ShovelTrove:Add(UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end

		if (input.UserInputType == Enum.UserInputType.MouseButton1) or (input.KeyCode == Enum.KeyCode.ButtonR2) then
			self:_Dig()

			disconnect()

			autoShovelConnect = RunService.Heartbeat:Connect(function()
				self:_Dig()
			end)
			self._ShovelTrove:Add(autoShovelConnect)

			inputChangedConnect = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					disconnect()
				end
			end)
			self._ShovelTrove:Add(inputChangedConnect)
		end
	end))

	self._ShovelTrove:Add(UserInputService.TouchTap:Connect(function(_, gpe)
		if gpe then return end
		self:_Dig()
	end))

	self:_DoShovelIdleAnim()
end

function DigController:_DoShovelIdleAnim()
	local character = Player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local animator : Animator = humanoid:FindFirstChildWhichIsA("Animator")
	if not animator then return end

	local track = animator:LoadAnimation(ShovelIdleAnimation)
	track.Priority = Enum.AnimationPriority.Idle
	track.Looped = true
	track:Play()
	self._ShovelTrove:Add(track, "Stop")
end

function DigController:_Dig()
	local character = Player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	local digCooldown = self:_GetDigCooldown()
	local currentTime = os.clock()
	if self._LastDig and currentTime < (self._LastDig + digCooldown) then return end

	self._LastDig = currentTime

	local track = animator:LoadAnimation(ShovelDigAnimation)
	while track.Length <= 0 do
		task.wait()
	end

	track.Priority = Enum.AnimationPriority.Action
	track.Looped = false
	track:Play()
	track:AdjustSpeed(math.max(1, track.Length / digCooldown))

	track:GetMarkerReachedSignal("Execute"):Connect(function()
		local dirtGuid = self:_GetNearestDirtGuid()
		if not dirtGuid then return end

		local dirt = self._Dirts[dirtGuid]
		self._NextPredictionId += 1
		local predictionId = self._NextPredictionId
		dirt:PredictHit(predictionId)

		self._DigService:Dig(dirtGuid, predictionId):andThen(function(succeeded)
			if not succeeded then
				dirt:CancelPredictedHit(predictionId)
			end
		end):catch(function()
			dirt:CancelPredictedHit(predictionId)
		end)
	end)
	self._DigTrack = track
end

return DigController
