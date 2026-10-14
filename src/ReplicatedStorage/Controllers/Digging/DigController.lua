local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local External = ReplicatedStorage:WaitForChild("External")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Animations = Assets:WaitForChild("Animations")
local ShovelModels : Folder = Assets:WaitForChild("Shovels")
local ShovelIdleAnimation : Animation = Animations:WaitForChild("ShovelIdle")
local ShovelDigAnimation : Animation = Animations:WaitForChild("ShovelDig")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Trove = require(External:WaitForChild("Trove"))
local ItemDef = require(ReplicatedConfigs:WaitForChild("ItemDef"))
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local Knit = require(External:WaitForChild("Knit"))
local Derpbar = require(ReplicatedStorage:WaitForChild("Derpbar"))
local Dirt = require(script.Parent:WaitForChild("Dirt"))

local DIG_BOX_WIDTH = 6
local DIG_BOX_VERTICAL_PADDING = 1
local DIG_RANGE = 8
local EQUIPPED_SHOVEL_NAME = "EquippedShovel"
local SHOVEL_MOTOR_NAME = "ShovelMotor6D"
local DirtFolder = Dirt.GetFolder()
local DirtOverlapParams = OverlapParams.new()
DirtOverlapParams.IncludeInstances = { DirtFolder }

local DigController = {
	Name = "DigController",
	_DigService = nil,
	_ReplicationController = nil,
	_ToolController = nil,
	_Dirts = {},
	_InitialDirtGuids = nil,
	_ShovelTrove = Trove.new(),
	_AttachedShovels = {},
	_ActiveShovelTool = nil,
	_LastDig = nil,
	_NextPredictionId = 0
}

function DigController:KnitStart()
	self._DigService = Knit.GetService("DigService")
	self._ReplicationController = require(ReplicatedStorage.Controllers.Replication.ReplicationController)
	self._ToolController = require(ReplicatedStorage.Controllers.Tools.ToolController)
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

	self._ToolController.ToolEquipped:Connect(function(player, character, tool)
		self:_OnToolEquipped(player, character, tool)
	end)
	self._ToolController.ToolUnequipped:Connect(function(player, character, tool)
		self:_OnToolUnequipped(player, character, tool)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		local tool = self._ToolController:GetEquippedToolForPlayer(player)
		if tool and player.Character then
			self:_OnToolEquipped(player, player.Character, tool)
		end
	end
end

function DigController:_OnToolEquipped(player, character, tool)
	local itemId = tool:GetAttribute("ItemId")
	local itemInfo = type(itemId) == "string" and ItemDef.GetItemInfo(itemId)
	if not itemInfo or itemInfo.Category ~= ItemDef.Categories.Shovel then return end
	if self._ToolController:GetEquippedToolForPlayer(player) ~= tool or tool.Parent ~= character then return end

	if player == Player and self._ActiveShovelTool ~= tool then
		self:SetupShovel(tool)
	end
	self:_AttachShovelToCharacter(player, character, tool, itemId)
end

function DigController:_OnToolUnequipped(player, character, tool)
	if player == Player and self._ActiveShovelTool == tool then
		self._ShovelTrove:Clean()
		self._ActiveShovelTool = nil
	end
	self:_RemoveShovelFromCharacter(character, tool)
end

function DigController:_GetShovelHandle(shovelModel)
	local primaryPart = shovelModel.PrimaryPart
	if primaryPart then return primaryPart end

	local handle = shovelModel:FindFirstChild("Handle", true)
	if handle and handle:IsA("BasePart") then return handle end

	return shovelModel:FindFirstChildWhichIsA("BasePart", true)
end

function DigController:_RemoveShovelFromCharacter(character, tool)
	local attached = self._AttachedShovels[character]
	if not attached or attached.Tool ~= tool then return end

	self._AttachedShovels[character] = nil
	attached.Model:Destroy()
end

function DigController:_AttachShovelToCharacter(player, character, tool, itemId)
	local rightHand = character:FindFirstChild("RightHand") or character:WaitForChild("RightHand", 5)
	if not rightHand or not rightHand:IsA("BasePart") then return end
	if player.Character ~= character or self._ToolController:GetEquippedToolForPlayer(player) ~= tool or tool.Parent ~= character then return end

	local shovelTemplate = ShovelModels:FindFirstChild(itemId) or ShovelModels:WaitForChild(itemId, 5)
	if not shovelTemplate or not shovelTemplate:IsA("Model") then return end
	if player.Character ~= character or self._ToolController:GetEquippedToolForPlayer(player) ~= tool or tool.Parent ~= character then return end

	local attached = self._AttachedShovels[character]
	if attached and attached.Tool == tool and attached.Model.Parent == character then return end
	if attached then
		attached.Model:Destroy()
		self._AttachedShovels[character] = nil
	end

	local shovelModel = shovelTemplate:Clone()
	local handle = self:_GetShovelHandle(shovelModel)
	if not handle or not handle:IsA("BasePart") then
		shovelModel:Destroy()
		return
	end

	UtilFunctions.AnchorAllDescendants(shovelModel, false)
	UtilFunctions.CanCollideAllDescendants(shovelModel, false)

	shovelModel.Name = EQUIPPED_SHOVEL_NAME
	shovelModel:SetAttribute("ItemId", itemId)
	shovelModel:PivotTo(rightHand:GetPivot())

	local motor = Instance.new("Motor6D")
	motor.Name = SHOVEL_MOTOR_NAME
	motor.C0 = CFrame.identity
	motor.C1 = CFrame.identity
	motor.Part0 = rightHand
	motor.Part1 = handle
	motor.Parent = handle

	self._AttachedShovels[character] = { Tool = tool, Model = shovelModel }
	shovelModel.Parent = character
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
	self._ActiveShovelTool = tool
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
