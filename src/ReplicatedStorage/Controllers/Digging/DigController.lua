local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local External = ReplicatedStorage:WaitForChild("External")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local ClientAssets = Assets:WaitForChild("ClientAssets")
local DigPowerGui = ClientAssets:WaitForChild("DigPowerGui")
local GuaranteedBoardGui = ClientAssets:WaitForChild("GuaranteedBoardGui")
local Animations = Assets:WaitForChild("Animations")
local ShovelModels : Folder = Assets:WaitForChild("Shovels")
local ShovelIdleAnimation : Animation = Animations:WaitForChild("ShovelIdle")
local ShovelDigAnimation : Animation = Animations:WaitForChild("ShovelDig")
local Sounds = Assets:WaitForChild("Sounds")
local DigSound = Sounds:WaitForChild("Dig")
local Particles = Assets:WaitForChild("Particles")
local DirtDigParticles = Particles:WaitForChild("DirtDigParticles")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local BigNumbers = require(External:WaitForChild("BigNumbers"))
local CountingText = require(GuiModules:WaitForChild("CountingText"))
local GuiObject = require(GuiModules:WaitForChild("Object"))
local GuiButton = require(GuiModules:WaitForChild("Button"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local Trove = require(External:WaitForChild("Trove"))
local ItemDef = require(ReplicatedConfigs:WaitForChild("ItemDef"))
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local RarityColorUtils = require(Utils:WaitForChild("RarityColorUtils"))
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local Knit = require(External:WaitForChild("Knit"))
local Derpbar = require(ReplicatedStorage:WaitForChild("Derpbar"))
local Dirt = require(script.Parent:WaitForChild("Dirt"))

local DIG_BOX_WIDTH = 6
local DIG_BOX_VERTICAL_PADDING = 1
local DIG_RANGE = 8
local TRAINING_HIT_DISTANCE = 2.5
local EQUIPPED_SHOVEL_NAME = "EquippedShovel"
local SHOVEL_MOTOR_NAME = "ShovelMotor6D"
local GUARANTEED_BOARD_TAG = "GuaranteedBoard"
local DirtFolder = Dirt.GetFolder()
local DirtOverlapParams = OverlapParams.new()
DirtOverlapParams.IncludeInstances = { DirtFolder }

local function getGuaranteedBoardAdornee(board)
	if board:IsA("BasePart") then
		return board
	elseif board:IsA("Model") then
		return board.PrimaryPart or board:FindFirstChildWhichIsA("BasePart", true)
	elseif board:IsA("Attachment") and GuaranteedBoardGui:IsA("BillboardGui") then
		return board
	end
end

local DigController = {
	Name = "DigController",
	_AfkController = nil,
	_DigService = nil,
	_EquipController = nil,
	_PlotController = nil,
	_PlayerStatsController = nil,
	_ReplicationController = nil,
	_TimeController = nil,
	_ToolController = nil,
	_PremiumController = nil,
	_Dirts = {},
	_GuaranteedBoards = {},
	_UpcomingGuaranteedSpawns = {},
	_InitialDirtGuids = nil,
	_ShovelTrove = Trove.new(),
	_AttachedShovels = {},
	_ActiveShovelTool = nil,
	_LastDig = nil,
	_LastTrainingDig = nil,
	_TrainingAnimator = nil,
	_TrainingTrack = nil,
	_TrainingMarkerConnection = nil,
	_TrainingActive = false,
	_WasOnExcavation = false,
	_RestoreExcavationAfter = nil,
	_DigPower = nil,
	_NextPredictionId = 0
}

function DigController:KnitInit()
	local hud = Player:WaitForChild("PlayerGui"):WaitForChild("Main"):WaitForChild("Hud")
	local digPowerFrame = hud:WaitForChild("DigPowerFrame")
	local amountFrame = digPowerFrame:WaitForChild("AmountFrame")

	self._DigPowerFrame = digPowerFrame
	self._DigTemplate = digPowerFrame:WaitForChild("Templates"):WaitForChild("DigTemplate")
	self._DigTemplate.Visible = false
	self._DigPowerAmountText = CountingText.new(amountFrame:WaitForChild("AmountText"))
	self._DigPowerDarkAmountText = CountingText.new(amountFrame:WaitForChild("DarkAmountText"))
	self._DigPowerGuiObject = GuiObject.new(digPowerFrame)
	self._DigPowerShadowTrove = Trove.new()

	local plusButton = GuiButton.new(self._DigPowerFrame.PlusButton)
	plusButton:SetCallback(function()
		self._PremiumController:OpenToFrame("DigPower")
	end)
end

function DigController:KnitStart()
	self._DigService = Knit.GetService("DigService")
	self._AfkController = require(ReplicatedStorage.Controllers.Afk.AfkController)
	self._EquipController = require(ReplicatedStorage.Controllers.Equips.EquipController)
	self._PlotController = require(ReplicatedStorage.Controllers.Plots.PlotController)
	self._PlayerStatsController = require(ReplicatedStorage.Controllers.PlayerStats.PlayerStatsController)
	self._ReplicationController = require(ReplicatedStorage.Controllers.Replication.ReplicationController)
	self._TimeController = require(ReplicatedStorage.Controllers.Time.TimeController)
	self._ToolController = require(ReplicatedStorage.Controllers.Tools.ToolController)
	self._PremiumController = require(ReplicatedStorage.Controllers.Premium.PremiumController)
	self._PlayerGui = Player:WaitForChild("PlayerGui")

	CollectionService:GetInstanceAddedSignal(GUARANTEED_BOARD_TAG):Connect(function(board)
		self:_AddGuaranteedBoard(board)
	end)
	CollectionService:GetInstanceRemovedSignal(GUARANTEED_BOARD_TAG):Connect(function(board)
		self:_RemoveGuaranteedBoard(board)
	end)
	for _, board in ipairs(CollectionService:GetTagged(GUARANTEED_BOARD_TAG)) do
		self:_AddGuaranteedBoard(board)
	end

	self._DigService.UpcomingGuaranteedSpawns:Observe(function(upcoming)
		self._UpcomingGuaranteedSpawns = upcoming or {}
		for _, boardState in pairs(self._GuaranteedBoards) do
			self:_RenderGuaranteedBoard(boardState)
		end
		self:_UpdateGuaranteedBoardCountdowns()
	end)
	self._TimeController.TimeUpdatedSignal:Connect(function()
		self:_UpdateGuaranteedBoardCountdowns()
	end)

	local teleportData = TeleportService:GetLocalPlayerTeleportData() or {}
	if teleportData.ReturnToExcavation then
		self._RestoreExcavationAfter = os.clock() + 1
	end

	self._PlayerStatsController.StatsUpdatedSignal:Connect(function()
		self:_UpdateDigPowerFrame()
	end)
	self:_UpdateDigPowerFrame()

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

	RunService.Heartbeat:Connect(function()
		self:_RestoreExcavationPosition()
		self:_UpdateExcavationTraining()
	end)
	Player.CharacterRemoving:Connect(function()
		if self._TrainingMarkerConnection then
			self._TrainingMarkerConnection:Disconnect()
			self._TrainingMarkerConnection = nil
		end
		if self._TrainingTrack then
			self._TrainingTrack:Destroy()
			self._TrainingTrack = nil
		end
		self._TrainingAnimator = nil
		self._TrainingActive = false
		self._WasOnExcavation = false
		self._AfkController.TeleportData.ReturnToExcavation = nil
	end)
end

function DigController:_AddGuaranteedBoard(board)
	if self._GuaranteedBoards[board] or not board:IsDescendantOf(Workspace) then
		return
	end

	local gui = GuaranteedBoardGui:Clone()
	gui.Adornee = board
	gui.Parent = self._PlayerGui

	local boardState = { Gui = gui, Rows = {} }
	self._GuaranteedBoards[board] = boardState
	self:_RenderGuaranteedBoard(boardState)
	self:_UpdateGuaranteedBoardCountdowns()
end

function DigController:_ClearGuaranteedBoardRows(boardState)
	for _, row in ipairs(boardState.Rows) do
		if row.Effect then
			row.Effect:Destroy()
		end
		row.Label:Destroy()
	end
	table.clear(boardState.Rows)
end

function DigController:_RemoveGuaranteedBoard(board)
	local boardState = self._GuaranteedBoards[board]
	if not boardState then
		return
	end

	self._GuaranteedBoards[board] = nil
	self:_ClearGuaranteedBoardRows(boardState)
	boardState.Gui:Destroy()
end

function DigController:_RenderGuaranteedBoard(boardState)
	self:_ClearGuaranteedBoardRows(boardState)

	local upcoming = table.clone(self._UpcomingGuaranteedSpawns)
	table.sort(upcoming, function(first, second)
		local firstRarityOrder = table.find(Constants.RarityOrder, first.Rarity) or 100000
		local secondRarityOrder = table.find(Constants.RarityOrder, second.Rarity) or 100000
		return firstRarityOrder < secondRarityOrder
	end)

	local gui = boardState.Gui
	local templateSource = gui.Templates.GuaranteedTemplate
	for order, spawn in ipairs(upcoming) do
		local label = templateSource:Clone()
		label.LayoutOrder = order
		label.Visible = true
		label.Parent = gui.GuaranteedList
		label.RarityText.Text = spawn.Rarity .. ":"
		local effect = RarityColorUtils.SetColor(label.RarityText, spawn.Rarity)
		table.insert(boardState.Rows, {
			Label = label,
			Effect = effect,
			Rarity = spawn.Rarity,
			SpawnsAt = spawn.SpawnsAt
		})
	end
end

function DigController:_UpdateGuaranteedBoardCountdowns()
	local now = Workspace:GetServerTimeNow()
	for _, boardState in pairs(self._GuaranteedBoards) do
		for _, row in ipairs(boardState.Rows) do
			local timeLeft = math.ceil(row.SpawnsAt - now)
			if timeLeft > 0 then
				row.Label.TimeText.Text = self._TimeController:GetTimeStringFromTime(timeLeft)
			else
				row.Label.TimeText.Text = "Spawning..."
			end
		end
	end
end

function DigController:_UpdateDigPowerFrame()
	local digPower = self._PlayerStatsController:GetStatValue(PlayerStatsEnum.DigPower)
	if not digPower then return end

	if self._DigPower == nil then
		self._DigPower = digPower
		self._DigPowerAmountText:Set(digPower)
		self._DigPowerDarkAmountText:Set(digPower)
		return
	end

	if digPower > self._DigPower then
		self:_PulseDigPowerShadows()
		self._DigPowerGuiObject:MakeThrob(1.1, 0.3)
		self:_ShowDigPowerEarned(digPower - self._DigPower)
	end

	self._DigPowerAmountText:Animate(digPower)
	self._DigPowerDarkAmountText:Animate(digPower)
	self._DigPower = digPower
end

function DigController:_PulseDigPowerShadows()
	self._DigPowerShadowTrove:Clean()

	local fadeInInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fadeOutInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	for _, shadow in ipairs(self._DigPowerFrame:QueryDescendants("UIShadow")) do
		shadow.Transparency = 1

		local fadeInTween = TweenService:Create(shadow, fadeInInfo, {
			Transparency = 0.2
		})
		local fadeOutTween = TweenService:Create(shadow, fadeOutInfo, {
			Transparency = 1
		})

		self._DigPowerShadowTrove:Add(fadeInTween)
		self._DigPowerShadowTrove:Add(fadeOutTween)
		self._DigPowerShadowTrove:Connect(fadeInTween.Completed, function(playbackState)
			if playbackState == Enum.PlaybackState.Completed then
				fadeOutTween:Play()
			end
		end)

		fadeInTween:Play()
	end
end

function DigController:_ShowDigPowerEarned(amount)
	local digPowerFrame = self._DigPowerFrame
	local digTemplate = self._DigTemplate:Clone()
	digTemplate.Text = string.format("+%s", BigNumbers.GetNumberDisplay(amount))
	digTemplate.ZIndex = 100000
	digTemplate.Visible = true
	digTemplate.Parent = digPowerFrame.Parent

	local parent = digPowerFrame.Parent :: GuiObject
	local originalSize = digTemplate.Size
	local guiInset = GuiService:GetGuiInset()
	local framePosition = digPowerFrame.AbsolutePosition - guiInset
	local parentPosition = parent.AbsolutePosition - guiInset
	local frameCenterX = framePosition.X + (digPowerFrame.AbsoluteSize.X / 2)
	local templateCenterY = framePosition.Y
	digTemplate.Position = UDim2.fromOffset(
		frameCenterX - parentPosition.X,
		templateCenterY - parentPosition.Y
	)
	digTemplate.Size = UDim2.fromScale(0, 0)

	local startPosition = digTemplate.Position
	local growTween = TweenService:Create(digTemplate, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = originalSize
	})
	local moveTween = TweenService:Create(digTemplate, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = startPosition + UDim2.fromOffset(0, -35)
	})

	growTween:Play()
	moveTween:Play()
	moveTween.Completed:Once(function(playbackState)
		if playbackState ~= Enum.PlaybackState.Completed then
			digTemplate:Destroy()
			return
		end

		local shrinkTween = TweenService:Create(digTemplate, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.fromScale(0, 0)
		})

		shrinkTween:Play()
		shrinkTween.Completed:Once(function()
			digTemplate:Destroy()
		end)
	end)
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

function DigController:_GetDigTrainingSpeed()
	return 1 -- Digs per second. Apply training speed upgrades here later.
end

function DigController:_GetDigTrainingCooldown()
	return 1 / self:_GetDigTrainingSpeed()
end

function DigController:_RestoreExcavationPosition()
	if not self._RestoreExcavationAfter or os.clock() < self._RestoreExcavationAfter then return end

	local plot = self._PlotController:GetPlot()
	local excavation = plot and plot.Instance:FindFirstChild("_Excavation")
	local part = excavation and excavation:IsA("Model") and excavation.PrimaryPart
	local character = Player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not part or not rootPart or not humanoid or humanoid.Health <= 0 then return end

	local feetToRoot = rootPart.Size.Y / 2 + humanoid.HipHeight
	local rootPosition = part.Position + Vector3.new(0, (part.Size.Y / 2 + feetToRoot + 0.1), 0)
	local rootCFrame = CFrame.new(rootPosition) * part.CFrame.Rotation
	character:PivotTo(rootCFrame * rootPart.CFrame:ToObjectSpace(character:GetPivot()))
	self._RestoreExcavationAfter = nil
end

function DigController:_IsOnExcavation()
	local plot = self._PlotController:GetPlot()
	local excavation = plot and plot.Instance:FindFirstChild("_Excavation")
	local part = excavation and excavation:IsA("Model") and excavation.PrimaryPart
	local character = Player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not part or not rootPart or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local feetPosition = rootPart.Position - Vector3.new(0, rootPart.Size.Y / 2 + humanoid.HipHeight, 0)
	local offset = part.CFrame:PointToObjectSpace(feetPosition)
	local withinFootprint = math.abs(offset.X) <= part.Size.X / 2
		and math.abs(offset.Z) <= part.Size.Z / 2
	local isOverPart = withinFootprint
	local lookOffset = part.CFrame:VectorToObjectSpace(rootPart.CFrame.LookVector)
	local forward = Vector2.new(lookOffset.X, lookOffset.Z)
	if forward.Magnitude > 0 then
		forward = forward.Unit * TRAINING_HIT_DISTANCE
	end
	local surfacePosition = part.CFrame:PointToWorldSpace(Vector3.new(
		math.clamp(offset.X + forward.X, -part.Size.X / 2, part.Size.X / 2),
		part.Size.Y / 2,
		math.clamp(offset.Z + forward.Y, -part.Size.Z / 2, part.Size.Z / 2)
	))
	return isOverPart, CFrame.new(surfacePosition) * part.CFrame.Rotation
end

function DigController:_EquipTrainingShovel()
	local character = Player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local shovelId = self._EquipController:GetEquippedItem(ItemDef.Categories.Shovel)
	if not shovelId then return false end

	local equippedTool = self._ToolController:GetEquippedToolForPlayer(Player)
	if equippedTool and equippedTool:GetAttribute("ItemId") == shovelId then
		return true
	end

	local backpack = Player:FindFirstChild("Backpack")
	if not backpack then return false end

	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and tool:GetAttribute("ItemId") == shovelId then
			humanoid:EquipTool(tool)
			break
		end
	end

	return false
end

function DigController:_PlayTrainingDigEffects(surfaceCFrame)
	local effectCFrame = surfaceCFrame + surfaceCFrame.UpVector * 0.1
	local random = Random.new()
	local part = Instance.new("Part")
	part.Color = Color3.fromRGB(106, 57, 9)
	part.Material = Enum.Material.Snow
	part.MaterialVariant = "Studs"
	UtilFunctions.DoFlyingDebris(part, Vector3.one * 0.5, {
		Count = math.random(4, 6),
		ExplosionOrigin = effectCFrame.Position,
		Force = random:NextNumber(17.5, 20),
		UpwardBias = 1.75,
		Lifetime = 1.25,
		CollisionGroup = "Debris"
	})

	local newDirtDigParticles = DirtDigParticles:Clone()
	newDirtDigParticles.Transparency = 1
	newDirtDigParticles.Anchored = true
	newDirtDigParticles.CanCollide = false
	newDirtDigParticles.CanQuery = false
	newDirtDigParticles.CFrame = effectCFrame
	UtilFunctions.DisableParticles(newDirtDigParticles)
	newDirtDigParticles.Parent = Workspace

	local _, longestEmitTime = UtilFunctions.GetLongestEmitter(newDirtDigParticles)
	Debris:AddItem(newDirtDigParticles, longestEmitTime)

	UtilFunctions.EmitParticles(newDirtDigParticles)
	UtilFunctions.PlaySoundAtLocation(DigSound, effectCFrame)
end

function DigController:_ShowTrainingPowerGain(rootPart, amount)
	if not rootPart or not rootPart:IsDescendantOf(Workspace) then return end

	local gui = DigPowerGui:Clone()
	gui.AmountFrame.AmountText.Text = "+" .. BigNumbers.GetNumberDisplay(amount)
	gui.Adornee = rootPart
	gui.AlwaysOnTop = true
	gui.Enabled = true

	local fullSize = gui.Size
	local startOffset = gui.StudsOffsetWorldSpace
	local side = math.random(0, 1) == 0 and -1 or 1
	local endOffset = startOffset + rootPart.CFrame.RightVector * (side * 2.5) + Vector3.new(0, 1.25, 0)
	gui.Size = UDim2.fromScale(0, 0)
	gui.Parent = rootPart

	local growTween = TweenService:Create(gui, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = fullSize
	})
	local flyTween = TweenService:Create(gui, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = endOffset
	})

	Debris:AddItem(gui, 2)
	flyTween.Completed:Once(function(playbackState)
		if playbackState ~= Enum.PlaybackState.Completed then
			gui:Destroy()
			return
		end

		local shrinkTween = TweenService:Create(gui, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.fromScale(0, 0)
		})
		shrinkTween.Completed:Once(function()
			gui:Destroy()
		end)
		shrinkTween:Play()
	end)

	growTween:Play()
	flyTween:Play()
end

function DigController:_TrainDigPower()
	local character = Player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	if self._TrainingAnimator ~= animator then
		if self._TrainingMarkerConnection then
			self._TrainingMarkerConnection:Disconnect()
		end
		if self._TrainingTrack then
			self._TrainingTrack:Destroy()
		end
		self._TrainingAnimator = animator
		self._TrainingTrack = animator:LoadAnimation(ShovelDigAnimation)
		self._TrainingTrack.Priority = Enum.AnimationPriority.Action
		self._TrainingTrack.Looped = false
		self._TrainingMarkerConnection = self._TrainingTrack:GetMarkerReachedSignal("Execute"):Connect(function()
			if not self._TrainingActive then return end
			local onExcavation, surfaceCFrame = self:_IsOnExcavation()
			if not onExcavation then return end
			self:_PlayTrainingDigEffects(surfaceCFrame)
			local character = Player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			self._DigService:TrainDigPower():andThen(function(powerGained)
				if typeof(powerGained) == "number" and powerGained > 0 then
					self:_ShowTrainingPowerGain(rootPart, powerGained)
				end
			end):catch(function() end)
		end)
	end

	local track = self._TrainingTrack
	if track.Length <= 0 then return end

	local cooldown = self:_GetDigTrainingCooldown()
	local currentTime = os.clock()
	if self._LastTrainingDig and currentTime < self._LastTrainingDig + cooldown then return end

	self._LastTrainingDig = currentTime
	track:Play(0.05, 1, math.max(1, track.Length / (cooldown * 0.9)))
end

function DigController:_UpdateExcavationTraining()
	local onExcavation = self:_IsOnExcavation()
	if self._WasOnExcavation and not onExcavation then
		local tool = self._ToolController:GetEquippedToolForPlayer(Player)
		local itemId = tool and tool:GetAttribute("ItemId")
		local itemInfo = itemId and ItemDef.GetItemInfo(itemId)
		local character = Player.Character
		local currentHumanoid = character and character:FindFirstChildOfClass("Humanoid")
		if itemInfo and itemInfo.Category == ItemDef.Categories.Shovel
			and tool.Parent == character and currentHumanoid then
			currentHumanoid:UnequipTools()
		end
	end
	self._WasOnExcavation = onExcavation

	if not onExcavation or not self:_EquipTrainingShovel() then
		local wasTraining = self._TrainingActive
		self._TrainingActive = false
		self._AfkController.TeleportData.ReturnToExcavation = nil
		if wasTraining and self._TrainingTrack then
			self._TrainingTrack:Stop(0.1)
		end
		return
	end

	self._TrainingActive = true
	self._AfkController.TeleportData.ReturnToExcavation = true
	self:_TrainDigPower()
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
	if self:_IsOnExcavation() then return end

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
