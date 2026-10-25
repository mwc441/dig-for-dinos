local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local External = ReplicatedStorage:WaitForChild("External")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local RevealPopSound = Sounds:WaitForChild("RevealPop")
local BonePileModels = Assets:WaitForChild("BonePiles")
local Animations = Assets:WaitForChild("Animations")
local BonePileHoldAnimation : Animation = Animations:WaitForChild("BonePileHold")
local BoneAssembleAnimation : Animation = Animations:WaitForChild("BoneAssemble")
local BonePickupSound = Sounds:WaitForChild("BonePickup")
local BoneRewardedSound = Sounds:WaitForChild("BoneRewarded")
local BoneGlowSound = Sounds:WaitForChild("BoneGlow")
local DinoPlacedSound = Sounds:WaitForChild("DinoPlaced")
local BrickSound = Sounds:WaitForChild("Brick")
local BoneFlySound = Sounds:WaitForChild("BoneFly")
local Particles = Assets:WaitForChild("Particles")
local RarityExplosions = Particles:WaitForChild("RarityExplosions")
local ClientAssets = Assets:WaitForChild("ClientAssets")
local RadiusPart = ClientAssets:WaitForChild("RadiusPart")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local DinosaurDef = require(ReplicatedConfigs:WaitForChild("DinosaurDef"))
local GuiButton = require(GuiModules:WaitForChild("Button"))
local BonePileUtils = require(Utils:WaitForChild("BonePileUtils"))
local DinosaurUtils = require(Utils:WaitForChild("DinosaurUtils"))
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local Knit = require(External:WaitForChild("Knit"))
local Derpbar = require(ReplicatedStorage:WaitForChild("Derpbar"))
local Ragdoll = require(Utils:WaitForChild("Ragdoll"))
local Trove = require(External:WaitForChild("Trove"))
local Device = require(External:WaitForChild("Device"))

local START_BONE_SCALE = 0.1
local ASSEMBLY_EXPLOSION_TIME = 0.5
local MAX_PLACEMENT_DISTANCE = 50
local REVEAL_ROLL_STEPS = 14

local function makeRevealSilhouette(template, scale, zoneId)
	local model = BonePileUtils.CreateModel(template.Name, scale, nil, zoneId)
	if not model then return end
	for _, instance in ipairs(model:GetDescendants()) do
		if instance:IsA("BasePart") then
			instance.Anchored = true
			instance.CanCollide = false
			instance.CanTouch = false
			instance.CanQuery = false
			instance.Color = Color3.new(0, 0, 0)
			instance.Material = Enum.Material.SmoothPlastic
			instance.MaterialVariant = ""
			instance.Reflectance = 0
			if instance:IsA("MeshPart") then
				instance.TextureID = ""
			end
		elseif instance:IsA("SpecialMesh") then
			instance.TextureId = ""
		elseif instance:IsA("SurfaceAppearance") or instance:IsA("Decal") or instance:IsA("Texture")
			or instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam")
			or instance:IsA("Highlight") or instance:IsA("BillboardGui") or instance:IsA("SurfaceGui")
			or instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight")
			or instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ProximityPrompt") then
			instance:Destroy()
		end
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "RevealHighlight"
	highlight.Adornee = model
	highlight.FillColor = Color3.new(0, 0, 0)
	highlight.FillTransparency = 0
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	return model
end

local BonePileController = {
	Name = "BonePileController",
	_PlotController = nil,
	_BonePileService = nil,
	_DinosaurController = nil,
	_DinosaurService = nil,
	_RewardsController = nil,
	_ToolController = nil,
	_ToolTrove = Trove.new(),
	_EquippedInventoryDisplays = {},
	_ActiveInventoryTool = nil,
	_BuildTrove = Trove.new()
}

function BonePileController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local hud = mainGui:WaitForChild("Hud")

	self._Gui = {
		DropButton = hud:WaitForChild("DropButton")
	}

	local dropButton = GuiButton.new(self._Gui.DropButton)
	dropButton:SetCallback(function()
		self._BonePileService:Drop()
	end)
	dropButton:SetButtonKeyCodes({ Enum.KeyCode.ButtonB })
end

function BonePileController:KnitStart()
	self._PlotController = require(ReplicatedStorage.Controllers.Plots.PlotController)
	self._DinosaurController = require(ReplicatedStorage.Controllers.Dinosaurs.DinosaurController)
	self._RewardsController = require(ReplicatedStorage.Controllers.Rewards.RewardsController)
	self._ToolController = require(ReplicatedStorage.Controllers.Tools.ToolController)
	self._BonePileService = Knit.GetService("BonePileService")
	self._DinosaurService = Knit.GetService("DinosaurService")

	self._BonePileService.CarriedDinosaurId:Observe(function(dinosaurId)
		if dinosaurId then
			Derpbar.Enabled = false

			self._Gui.DropButton.Visible = true

			UtilFunctions.PlayCopyOfSound(BonePickupSound)

			self:_DoBonePileHoldAnim()
		else
			Derpbar.Enabled = true
			self._Gui.DropButton.Visible = false
			self:_StopBonePileHoldAnim()
		end
	end)

	self._BonePileService.BonesRewarded:Connect(function()
		UtilFunctions.PlayCopyOfSound(BoneRewardedSound)
	end)
	self._BonePileService.RevealStarted:Connect(function(reveal)
		self:_PlayReveal(reveal)
	end)

	self._ToolController.ToolEquipped:Connect(function(player, character, tool)
		self:_OnInventoryToolEquipped(player, character, tool)
	end)
	self._ToolController.ToolUnequipped:Connect(function(player, character, tool)
		self:_OnInventoryToolUnequipped(player, character, tool)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		local tool = self._ToolController:GetEquippedToolForPlayer(player)
		if tool and player.Character then
			self:_OnInventoryToolEquipped(player, player.Character, tool)
		end
	end
end

function BonePileController:_PlayReveal(reveal)
	local templates = {}
	for _, template in ipairs(BonePileModels:GetChildren()) do
		if template:IsA("Model") and template.PrimaryPart and DinosaurDef.GetDinosaurInfo(template.Name) then
			table.insert(templates, template)
		end
	end
	if #templates == 0 then
		return
	end
	table.sort(templates, function(first, second)
		return first.Name < second.Name
	end)

	local random = Random.new()
	local rolls = {}
	local previousTemplate
	for step = 1, REVEAL_ROLL_STEPS do
		local template = templates[random:NextInteger(1, #templates)]
		if #templates > 1 and template == previousTemplate then
			local index = table.find(templates, template)
			template = templates[index % #templates + 1]
		end
		rolls[step] = {
			Template = template,
			Scale = reveal.Scale
		}
		previousTemplate = template
	end

	local officialTemplate = BonePileModels:FindFirstChild(reveal.DinosaurId)
	if officialTemplate and officialTemplate:IsA("Model") then
		rolls[REVEAL_ROLL_STEPS] = { Template = officialTemplate, Scale = reveal.Scale }
	end

	local currentModel
	local currentScale
	local lastStep
	local finalShown = false
	local connection

	local function setModel(model, scale)
		if currentModel then
			currentModel:Destroy()
		end
		currentModel = model
		currentScale = scale
	end

	local function placeModel(growth)
		currentModel:ScaleTo(currentScale * math.max(0.01, growth))
		currentModel:PivotTo(reveal.DropCFrame)
		if not currentModel.Parent then
			currentModel.Parent = Workspace
		end
	end

	local function update()
		local now = Workspace:GetServerTimeNow()
		if now >= reveal.EndsAt then
			connection:Disconnect()
			setModel(nil)
			return
		end

		local elapsed = math.max(0, now - reveal.StartsAt)
		if now < reveal.RollEndsAt then
			local progress = math.clamp(elapsed / (reveal.RollEndsAt - reveal.StartsAt), 0, 1)
			local rollPosition = REVEAL_ROLL_STEPS * (1 - (1 - progress) ^ 2)
			local step = math.min(REVEAL_ROLL_STEPS, math.floor(rollPosition) + 1)
			if step ~= lastStep then
				lastStep = step
				local choice = rolls[step]
				setModel(makeRevealSilhouette(choice.Template, choice.Scale, reveal.ZoneId), choice.Scale)
				if currentModel then
					local popSound = RevealPopSound:Clone()
					popSound.PlaybackSpeed = random:NextNumber(0.95, 1.05)
					UtilFunctions.PlaySoundAtLocation(popSound, reveal.DirtCFrame)
					popSound:Destroy()
				end
			end
			if currentModel then
				local stepProgress = rollPosition - (step - 1)
				local growth = TweenService:GetValue(math.clamp(stepProgress / 0.7, 0, 1),
					Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				placeModel(growth)
			end
		else
			if not finalShown then
				finalShown = true
				local model = BonePileUtils.CreateModel(reveal.DinosaurId, reveal.Scale, reveal.Mutation, reveal.ZoneId)
				if model then
					UtilFunctions.AnchorAllDescendants(model, true)
					UtilFunctions.CanQueryAllDescendants(model, false)
				end
				setModel(model, reveal.Scale)

				UtilFunctions.PlaySoundAtLocation(BoneRewardedSound, reveal.DirtCFrame)
			end
			if currentModel then
				local progress = math.clamp((now - reveal.RollEndsAt) / (reveal.EndsAt - reveal.RollEndsAt), 0, 1)
				local growth = TweenService:GetValue(math.clamp(progress / 0.6, 0, 1),
					Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				placeModel(growth)
			end
		end
	end

	connection = RunService.Heartbeat:Connect(update)
	update()
end

function BonePileController:_OnInventoryToolEquipped(player, character, tool)
	local guid = tool:GetAttribute("BonePileGuid")
	local dinosaurId = tool:GetAttribute("DinosaurId")
	if not guid or type(dinosaurId) ~= "string" then return end
	if self._ToolController:GetEquippedToolForPlayer(player) ~= tool or tool.Parent ~= character then return end

	if player == Player and self._ActiveInventoryTool ~= tool then
		self._ToolTrove:Clean()
		self._ActiveInventoryTool = tool
		self:_DoBonePileHoldAnim()
			self:_StartBuildMode(guid, dinosaurId, tool:GetAttribute("Scale"), tool:GetAttribute("Mutation"), tool:GetAttribute("ZoneId"))
		self._ToolTrove:Add(function()
			self:_StopBuildMode()
		end)
	end

	self:_AttachInventoryToolDisplay(player, character, tool, dinosaurId)
end

function BonePileController:_OnInventoryToolUnequipped(player, character, tool)
	if player == Player and self._ActiveInventoryTool == tool then
		self:_StopBonePileHoldAnim()
		self._ToolTrove:Clean()
		self._ActiveInventoryTool = nil
	end

	local display = self._EquippedInventoryDisplays[character]
	if display and display.Tool == tool then
		self._EquippedInventoryDisplays[character] = nil
		display.Model:Destroy()
	end
end

function BonePileController:_AttachInventoryToolDisplay(player, character, tool, dinosaurId)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
		or character:WaitForChild("HumanoidRootPart", 5)
	if not torso then return end
	if player.Character ~= character or self._ToolController:GetEquippedToolForPlayer(player) ~= tool or tool.Parent ~= character then return end

	local bonePileModels = Assets:FindFirstChild("BonePiles") or Assets:WaitForChild("BonePiles", 5)
	if not bonePileModels then return end
	local template = bonePileModels:FindFirstChild(dinosaurId) or bonePileModels:WaitForChild(dinosaurId, 5)
	if not template then return end
	if player.Character ~= character or self._ToolController:GetEquippedToolForPlayer(player) ~= tool or tool.Parent ~= character then return end

	local display = self._EquippedInventoryDisplays[character]
	if display and display.Tool == tool and display.Model.Parent == character then return end

	local model = BonePileUtils.CreateModel(dinosaurId, tool:GetAttribute("Scale"), tool:GetAttribute("Mutation"), tool:GetAttribute("ZoneId"))
	if not model then return end
	if display then
		display.Model:Destroy()
	end

	model.Name = "EquippedBonePile"
	BonePileUtils.CarryPileModel(model, character)
	self._EquippedInventoryDisplays[character] = { Tool = tool, Model = model }
	model.Parent = character
end

function BonePileController:_DoBonePileHoldAnim()
	self:_StopBonePileHoldAnim()

	local character = Player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildWhichIsA("Animator")
	if not animator then return end

	local track = animator:LoadAnimation(BonePileHoldAnimation)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Idle
	track:Play()
	self._BonePileHoldTrack = track
end

function BonePileController:_StopBonePileHoldAnim()
	if self._BonePileHoldTrack then
		self._BonePileHoldTrack:Stop()
		self._BonePileHoldTrack = nil
	end
end

-- BUILD STUFF
function BonePileController:_IsMobilePlacement()
	return Device.GetUserDevice() == "Mobile"
end

function BonePileController:_GetPlacementRay(camera: Camera)
	if self:_IsMobilePlacement() then
		local viewportSize = camera.ViewportSize
		return camera:ViewportPointToRay(viewportSize.X * 0.5, viewportSize.Y * 0.4)
	end

	local mousePos = UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(mousePos.X, mousePos.Y)
end

function BonePileController:_StartBuildMode(bonePileGuid, dinosaurId, scale, mutation, zoneId)
	local function isWithinPlacementDistance(position)
		local character = Player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		return rootPart and (position - rootPart.Position).Magnitude <= MAX_PLACEMENT_DISTANCE
	end

	local floorPreview = Instance.new("Part")
	floorPreview.Name = "BuildFloorPreview"
	floorPreview.Material = Enum.Material.Glass
	floorPreview.Anchored = true
	floorPreview.CanCollide = false
	floorPreview.CanTouch = false
	floorPreview.CanQuery = false
	floorPreview.CastShadow = false
	floorPreview.Transparency = 1
	self._BuildTrove:Add(floorPreview)

	local floorHighlight = Instance.new("Highlight")
	floorHighlight.Name = "BuildFloorHighlight"
	floorHighlight.FillColor = Color3.fromRGB(255, 255, 255)
	floorHighlight.FillTransparency = 0.85
	floorHighlight.OutlineColor = Color3.fromRGB(0, 0, 0)
	floorHighlight.OutlineTransparency = 0
	floorHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	floorHighlight.Adornee = floorPreview
	floorHighlight.Parent = floorPreview

	self._BuildTrove:Add(RunService.Heartbeat:Connect(function()
		local plot = self._PlotController:GetPlot()
		local floor : BasePart = plot and plot.Instance:FindFirstChild("_Floor")
		if not floor then
			floorPreview.Parent = nil
			return
		end

		floorPreview.Size = floor.Size
		floorPreview.CFrame = floor.CFrame
		floorPreview.Color = floor.Color
		if floorPreview.Parent ~= Workspace then
			floorPreview.Parent = Workspace
		end

		local camera = Workspace.CurrentCamera

		local ray = self:_GetPlacementRay(camera)

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		raycastParams.FilterDescendantsInstances = { floor }

		local raycastResult : RaycastResult = Workspace:Raycast(ray.Origin, ray.Direction.Unit * 500, raycastParams)
		if raycastResult and isWithinPlacementDistance(raycastResult.Position) then
			self._PlacementCFrame = CFrame.new(raycastResult.Position) * floor.CFrame.Rotation

			if not self._PlacementModel then
				local newBonePileModel = BonePileUtils.CreateModel(dinosaurId, scale, mutation, zoneId)
				newBonePileModel.Parent = Workspace
				self._BuildTrove:Add(newBonePileModel)
				self._PlacementModel = newBonePileModel
			end

			local _, bonePileSize = self._PlacementModel:GetBoundingBox()

			if not self._PlacementRadius then
				local newRadiusPart = RadiusPart:Clone()

				local radius = math.max(bonePileSize.X, bonePileSize.Z)
				newRadiusPart.Size = Vector3.new(newRadiusPart.Size.X, radius, radius)
				newRadiusPart.Color = Color3.fromRGB(0, 255, 0)
				newRadiusPart.Parent = Workspace
				self._PlacementRadius = newRadiusPart
				self._BuildTrove:Add(self._PlacementRadius)
			end

			local bonePileCFrame = self._PlacementCFrame * CFrame.new(0, bonePileSize.Y / 2, 0)
			UtilFunctions.MoveModelByBoundingBox(self._PlacementModel, bonePileCFrame)

			local radiusSize = self._PlacementRadius.Size
			self._PlacementRadius:PivotTo(self._PlacementCFrame * CFrame.new(0, radiusSize.X, 0))
		else
			if self._PlacementModel then
				self._BuildTrove:Remove(self._PlacementModel)
				self._PlacementModel = nil
			end

			if self._PlacementRadius then
				self._BuildTrove:Remove(self._PlacementRadius)
				self._PlacementRadius = nil
			end

			self._PlacementCFrame = nil
		end
	end))

	self._BuildTrove:Add(UserInputService.InputEnded:Connect(function(input, gpe)
		if gpe then return end

		if (input.UserInputType == Enum.UserInputType.MouseButton1) or (input.KeyCode == Enum.KeyCode.ButtonR2) then
			if self._PlacementCFrame and isWithinPlacementDistance(self._PlacementCFrame.Position) then
				self:_PlayBoneAssembleAnimation(bonePileGuid, dinosaurId, scale, mutation, zoneId, self._PlacementCFrame)
			end
		end
	end))

	self._BuildTrove:Add(UserInputService.TouchTap:Connect(function(_, gpe)
		if gpe then return end

		if self._PlacementCFrame and isWithinPlacementDistance(self._PlacementCFrame.Position) then
			self:_PlayBoneAssembleAnimation(bonePileGuid, dinosaurId, scale, mutation, zoneId, self._PlacementCFrame)
		end
	end))
end

function BonePileController:_PlayBoneAssembleAnimation(bonePileGuid, dinosaurId, scale, mutation, zoneId, cframe)
	if self._IsAssembling or typeof(cframe) ~= "CFrame" then return end

	if self._DinosaurController:IsAtMaxCapacity() then
		self._RewardsController:AnnounceMessage("❌ Your plot is full!", Color3.fromRGB(255, 85, 85))
		return
	end

	local character = Player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local animator = humanoid:FindFirstChildWhichIsA("Animator")
	if not animator then return end

	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	if not torso then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local model = DinosaurUtils.CreateModel(dinosaurId, scale, mutation)
	if not model then return end

	local info = DinosaurDef.GetDinosaurInfo(dinosaurId)
	if not info then return end

	DinosaurUtils.PositionAtGround(model, cframe)
	model.Name = dinosaurId .. "Skeleton"

	local parts = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 then
			table.insert(parts, descendant)
		end
	end

	table.sort(parts, function(a, b)
		return a.Position.Y < b.Position.Y
	end)

	if #parts == 0 then
		model:Destroy()
		return
	end

	local flightFolder = Instance.new("Folder")
	flightFolder.Name = "Assembling" .. dinosaurId
	flightFolder.Parent = Workspace

	local random = Random.new()
	local launchInterval = math.min(0.1, 1.5 / math.max(#parts - 1, 1))
	local flights = {}
	for index, part in ipairs(parts) do
		flights[index] = { Target = part, StartTime = 0.2 + (index - 1) * launchInterval }
	end

	local track = animator:LoadAnimation(BoneAssembleAnimation)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Action

	local oldWalkSpeed = humanoid.WalkSpeed
	local oldAutoRotate = humanoid.AutoRotate
	local oldDerpbarEnabled = Derpbar.Enabled
	self._IsAssembling = true
	self._DinosaurController:HideDinosaurs()
	self:_StopBuildMode()
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	local lookPosition = Vector3.new(cframe.Position.X, rootPart.Position.Y, cframe.Position.Z)
	if (lookPosition - rootPart.Position).Magnitude > 0.01 then
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, lookPosition)
	end
	humanoid:UnequipTools()
	Derpbar.Enabled = false

	local pileModel = BonePileUtils.CreateModel(dinosaurId, scale, mutation, zoneId)
	if pileModel then
		local function removeTags(instance)
			for _, tag in ipairs(CollectionService:GetTags(instance)) do
				CollectionService:RemoveTag(instance, tag)
			end
		end

		removeTags(pileModel)
		for _, descendant in ipairs(pileModel:GetDescendants()) do
			removeTags(descendant)
		end
		pileModel.Name = "AssemblingBonePile"
		BonePileUtils.CarryPileModel(pileModel, character)
		pileModel.Parent = character
	end
	local initialPileScale = pileModel and pileModel:GetScale()
	local launchedCount = 0
	track:Play()

	local elapsed = 0
	local completedCount = 0
	local finished = false
	local flyingFinished = false
	local dinosaursHidden = true
	local completionPhase
	local completionElapsed = 0
	local flightConnection
	local diedConnection
	local removingConnection

	local glowTime = BoneGlowSound.TimeLength

	local function showDinosaurs()
		if not dinosaursHidden then return end
		dinosaursHidden = false
		self._DinosaurController:ShowDinosaurs()
	end

	local function finishFlying()
		if flyingFinished then return end
		flyingFinished = true

		track:Stop(0.15)

		if humanoid.Parent == character then
			humanoid.WalkSpeed = oldWalkSpeed
			humanoid.AutoRotate = oldAutoRotate
		end
		Derpbar.Enabled = oldDerpbarEnabled
	end

	local function finish()
		if finished then return end
		finished = true

		if flightConnection then flightConnection:Disconnect() end
		if diedConnection then diedConnection:Disconnect() end
		if removingConnection then removingConnection:Disconnect() end
		finishFlying()
		flightFolder:Destroy()
		model:Destroy()
		if pileModel then pileModel:Destroy() end
		self._IsAssembling = false
		showDinosaurs()
	end

	local function startGlow()
		completionPhase = "Glow"
		completionElapsed = 0

		UtilFunctions.PlaySoundAtLocation(BoneGlowSound, cframe)

		for _, flight in ipairs(flights) do
			local part = flight.Part
			local glowPart = part:Clone()
			local glowTrail
			for _, descendant in ipairs(glowPart:GetDescendants()) do
				if descendant:IsA("Trail") then
					descendant.Enabled = false
					glowTrail = descendant
				elseif descendant:IsA("SurfaceAppearance") or descendant:IsA("Decal") or descendant:IsA("Texture") or descendant:IsA("ParticleEmitter") then
					descendant:Destroy()
				end
			end
			if glowPart:IsA("MeshPart") then
				glowPart.TextureID = ""
			end
			glowPart.Material = Enum.Material.Neon
			glowPart.MaterialVariant = ""
			glowPart.Color = Color3.new(1, 1, 1)
			glowPart.Transparency = 1
			glowPart.Size = part.Size * 1.01
			glowPart.Parent = flightFolder

			flight.GlowPart = glowPart
			flight.GlowTrail = glowTrail
			flight.OriginalColor = part.Color
			flight.OriginalTransparency = part.Transparency
		end
	end

	local function startExplosion()
		completionPhase = "Explosion"
		completionElapsed = 0
		local center = model:GetPivot().Position

		showDinosaurs()
		self._DinosaurService:PlaceDinosaur(bonePileGuid, cframe)
		UtilFunctions.PlaySoundAtLocation(DinoPlacedSound, cframe)

		local rarityExplosion = RarityExplosions:FindFirstChild(info.Rarity) :: BasePart
		if rarityExplosion then
			local newRarityExplosion = rarityExplosion:Clone()
			newRarityExplosion.Transparency = 1
			newRarityExplosion.CanCollide = false
			newRarityExplosion.CFrame = model:GetPivot()
			newRarityExplosion.Parent = Workspace
			local _, longestEmitTime = UtilFunctions.GetLongestEmitter(newRarityExplosion)
			UtilFunctions.EmitParticles(newRarityExplosion)
			Debris:AddItem(newRarityExplosion, longestEmitTime)
		end

		for _, flight in ipairs(flights) do
			flight.Part:Destroy()
			flight.Part = flight.GlowPart
			flight.Trail = flight.GlowTrail
			flight.GlowPart = nil
			flight.GlowTrail = nil
			flight.Trail.Enabled = true

			local part = flight.Part
			local radial = Vector3.new(part.Position.X - center.X, 0, part.Position.Z - center.Z)
			if radial.Magnitude < 0.05 then
				local angle = random:NextNumber(0, math.pi * 2)
				radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
			end

			flight.ExplosionStart = part.CFrame
			flight.ExplosionDirection = (radial.Unit + Vector3.new(
				random:NextNumber(-0.3, 0.3),
				random:NextNumber(-0.6, 0.6),
				random:NextNumber(-0.3, 0.3)
			)).Unit
			flight.ExplosionDistance = random:NextNumber(15, 20)
			flight.ExplosionSpin = Vector3.new(
				random:NextNumber(-math.pi, math.pi),
				random:NextNumber(-math.pi, math.pi),
				random:NextNumber(-math.pi, math.pi)
			)
		end
	end

	diedConnection = humanoid.Died:Connect(function()
		finish()
	end)
	removingConnection = Player.CharacterRemoving:Connect(function(removingCharacter)
		if removingCharacter == character then
			finish()
		end
	end)

	flightConnection = RunService.Heartbeat:Connect(function(dt)
		if completionPhase == "Glow" then
			completionElapsed += dt
			local alpha = math.clamp(completionElapsed / glowTime, 0, 1)
			local easedAlpha = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			for _, flight in ipairs(flights) do
				flight.Part.Color = flight.OriginalColor:Lerp(Color3.new(1, 1, 1), easedAlpha)
				flight.GlowPart.Transparency = 1 - (1 - flight.OriginalTransparency) * easedAlpha
			end
			if alpha >= 1 then startExplosion() end
			return
		elseif completionPhase == "Explosion" then
			completionElapsed += dt
			local alpha = math.clamp(completionElapsed / ASSEMBLY_EXPLOSION_TIME, 0, 1)
			local travel = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local fadeAlpha = TweenService:GetValue(math.clamp((alpha - 0.4) / 0.6, 0, 1), Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			for _, flight in ipairs(flights) do
				local start = flight.ExplosionStart
				local spin = flight.ExplosionSpin
				local position = start.Position + flight.ExplosionDirection * flight.ExplosionDistance * travel
				flight.Part.CFrame = CFrame.new(position) * start.Rotation * CFrame.Angles(spin.X * travel, spin.Y * travel, spin.Z * travel)
				flight.Part.Transparency = flight.OriginalTransparency + (1 - flight.OriginalTransparency) * fadeAlpha
			end
			if alpha >= 1 then finish() end
			return
		end

		elapsed += dt

		for index, flight in ipairs(flights) do
			if elapsed < flight.StartTime or flight.Done then continue end

			if not flight.Part then
				launchedCount += 1
				if pileModel then
					if launchedCount == #flights then
						pileModel:Destroy()
						pileModel = nil
					else
						pileModel:ScaleTo(initialPileScale * math.max(0.2, 1 - launchedCount / #flights))
					end
				end

				local target = flight.Target
				local startPosition = BonePileUtils.GetCarryCFrame(torso).Position
				local endPosition = target.Position
				local distance = (endPosition - startPosition).Magnitude
				local startRotation = torso.CFrame.Rotation * CFrame.Angles(
					random:NextNumber(-math.pi, math.pi),
					random:NextNumber(-math.pi, math.pi),
					random:NextNumber(-math.pi, math.pi)
				)

				local newBoneFlySound = BoneFlySound:Clone()
				newBoneFlySound.PlaybackSpeed = random:NextNumber(0.9, 1.1)
				UtilFunctions.PlaySoundAtLocation(newBoneFlySound, CFrame.new(startPosition))
				newBoneFlySound:Destroy()

				local flightPart = target:Clone()
				for _, descendant in ipairs(flightPart:GetDescendants()) do
					if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") or descendant:IsA("Constraint") then
						descendant:Destroy()
					end
				end
				flightPart.Anchored = true
				flightPart.CanCollide = false
				flightPart.CanQuery = false
				flightPart.CanTouch = false
				flightPart.Size = target.Size * START_BONE_SCALE
				flightPart.CFrame = CFrame.new(startPosition) * startRotation

				local trailTop = Instance.new("Attachment")
				trailTop.Position = Vector3.new(0, 0.225, 0)
				trailTop.Parent = flightPart
				local trailBottom = Instance.new("Attachment")
				trailBottom.Position = Vector3.new(0, -0.225, 0)
				trailBottom.Parent = flightPart

				local trail = Instance.new("Trail")
				trail.Attachment0 = trailTop
				trail.Attachment1 = trailBottom
				trail.Color = ColorSequence.new(Color3.new(1, 1, 1))
				trail.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.15),
					NumberSequenceKeypoint.new(1, 1)
				})
				trail.WidthScale = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(1, 0)
				})
				trail.Lifetime = 0.3
				trail.MinLength = 0.05
				trail.LightEmission = 1
				trail.FaceCamera = true
				trail.Parent = flightPart
				flightPart.Parent = flightFolder

				flight.Part = flightPart
				flight.Trail = trail
				flight.GoalSize = target.Size
				flight.StartPosition = startPosition
				flight.StartRotation = startRotation
				flight.ControlPosition = (startPosition + endPosition) / 2
					+ Vector3.yAxis * (2 + distance * 0.2)
					+ torso.CFrame.RightVector * random:NextNumber(-8, 8)
				flight.Duration = 0.75
			end

			local alpha = math.clamp((elapsed - flight.StartTime) / flight.Duration, 0, 1)
			local easedAlpha = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			local targetCFrame = flight.Target.CFrame
			local position = UtilFunctions.QuadraticBezier(
				flight.StartPosition,
				flight.ControlPosition,
				targetCFrame.Position,
				easedAlpha
			)
			local sizeAlpha = TweenService:GetValue(alpha, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
			local boneScale = START_BONE_SCALE + (1 - START_BONE_SCALE) * sizeAlpha
			flight.Part.Size = flight.GoalSize * boneScale
			flight.Part.CFrame = CFrame.new(position) * flight.StartRotation:Lerp(targetCFrame.Rotation, easedAlpha)

			if alpha >= 1 then
				local newBrickSound = BrickSound:Clone()
				newBrickSound.PlaybackSpeed = random:NextNumber(0.95, 1.05)
				UtilFunctions.PlaySoundAtLocation(newBrickSound, flight.Part.CFrame)
				newBrickSound:Destroy()
				flight.Done = true
				flight.Trail.Enabled = false
				completedCount += 1
			end
		end

		if completedCount == #flights then
			finishFlying()
			startGlow()
		end
	end)
end

function BonePileController:_StopBuildMode()
	self._PlacementCFrame = nil
	self._PlacementModel = nil
	self._PlacementRadius = nil

	self._BuildTrove:Clean()
end

return BonePileController
