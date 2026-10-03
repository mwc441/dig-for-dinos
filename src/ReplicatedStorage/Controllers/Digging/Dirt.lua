local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local ClientAssets = Assets:WaitForChild("ClientAssets")
local DirtGui = ClientAssets:WaitForChild("DirtGui")
local DamageGui = ClientAssets:WaitForChild("DamageGui")
local DirtModels = Assets:WaitForChild("Dirt")
local Sounds = Assets:WaitForChild("Sounds")
local DirtSpawnSound = Sounds:WaitForChild("DirtSpawn")
local DigSound = Sounds:WaitForChild("Dig")
local Particles = Assets:WaitForChild("Particles")
local DirtDigParticles = Particles:WaitForChild("DirtDigParticles")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local DirtDef = require(ReplicatedConfigs:WaitForChild("DirtDef"))
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local Trove = require(External:WaitForChild("Trove"))
local BigNumbers = require(External:WaitForChild("BigNumbers"))

local StageOneModel = DirtModels:WaitForChild("1")
local StageModels = {}

for _, child in ipairs(DirtModels:GetChildren()) do
	local stageNumber = tonumber(child.Name)
	if child:IsA("Model") and stageNumber and stageNumber >= 1 and stageNumber % 1 == 0 then
		table.insert(StageModels, child)
	end
end

table.sort(StageModels, function(first, second)
	return tonumber(first.Name) < tonumber(second.Name)
end)

assert(#StageModels > 0, "Assets.Dirt needs at least one numbered model")

local SPAWN_DEPTH = 3
local SPAWN_DURATION = 2
local SPAWN_SHAKE_SPEED = 45
local SPAWN_SHAKE_DISTANCE = 1
local SPAWN_SHAKE_ANGLE = math.rad(3)
local HIT_DURATION = 0.4
local HIT_SHAKE_SPEED = 55
local HIT_SHAKE_DISTANCE = 0.6
local HIT_SHAKE_ANGLE = 0
local HIT_DIP_DISTANCE = 0
local DAMAGE_GUI_RISE = 2.5
local DAMAGE_GUI_GROW_TIME = 0.18
local DAMAGE_GUI_HOLD_TIME = 0.2
local DAMAGE_GUI_SHRINK_TIME = 0.25

local DirtFolder = Instance.new("Folder")
DirtFolder.Name = "_Dirt"
DirtFolder.Parent = Workspace

local Dirt = {}
Dirt.__index = Dirt

function Dirt.GetFolder()
	return DirtFolder
end

function Dirt.new(replicationData, animateSpawn)
	local self = setmetatable({}, Dirt)
	self._Guid = replicationData.Guid
	self._DirtId = replicationData.DirtId
	self._Stage = nil
	self._Model = nil
	self._CFrame = replicationData.CFrame
	self._Scale = replicationData.Scale
	self._SpawnOffset = CFrame.identity
	self._HitOffset = CFrame.identity
	self._HitElapsed = nil
	if animateSpawn then
		self._SpawnOffset = CFrame.new(0, -SPAWN_DEPTH * self._Scale, 0)
	end
	self._DisplayCFrame = self._CFrame * self._SpawnOffset
	self._Health = replicationData.Health
	self._TotalHealth = replicationData.TotalHealth
	self._PredictedHits = {}

	self._Trove = Trove.new()

	self:_Setup()

	self:Update(replicationData)
	if animateSpawn then
		self:_AnimateSpawn()
	end

	return self
end

function Dirt:GetModel()
	return self._Model
end

function Dirt:GetCFrame()
	return self._CFrame
end

function Dirt:GetDirtId()
	return self._DirtId
end

function Dirt:GetScale()
	return self._Scale
end

function Dirt:PredictHit(predictionId)
	self._PredictedHits[predictionId] = true
	self:_AnimateHit()
end

function Dirt:CancelPredictedHit(predictionId)
	self._PredictedHits[predictionId] = nil
end

function Dirt:_Setup()
	local rootPart = Instance.new("Part")
	rootPart.CFrame = self._DisplayCFrame
	rootPart.Anchored = true
	rootPart.Transparency = 1
	rootPart.CanCollide = false
	rootPart.CanQuery = false
	rootPart.CanTouch = false
	rootPart.Parent = Workspace

	self._RootPart = rootPart
	self._Trove:Add(self._RootPart)

	self:_SetupDirtGui()
end

function Dirt:_ApplyDisplayCFrame()
	self._DisplayCFrame = self._CFrame * self._SpawnOffset * self._HitOffset
	self._Model:PivotTo(self._DisplayCFrame)
	self._RootPart.CFrame = self._DisplayCFrame
end

function Dirt:_AnimateSpawn()
	local elapsed = 0
	local shakeElapsed = 0
	local shakeInterval = math.pi / SPAWN_SHAKE_SPEED
	local previousShake = Vector2.zero
	local random = Random.new()
	local angle = random:NextNumber(0, math.pi * 2)
	local nextShake = Vector2.new(math.cos(angle), math.sin(angle)) * random:NextNumber(0.5, 1)

	UtilFunctions.PlaySoundAtLocation(DirtSpawnSound, self._CFrame)

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed = math.min(elapsed + dt, SPAWN_DURATION)
		shakeElapsed += dt
		while shakeElapsed >= shakeInterval do
			shakeElapsed -= shakeInterval
			previousShake = nextShake
			angle = random:NextNumber(0, math.pi * 2)
			nextShake = Vector2.new(math.cos(angle), math.sin(angle)) * random:NextNumber(0.5, 1)
		end

		local progress = elapsed / SPAWN_DURATION
		local rise = TweenService:GetValue(progress, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local shakeBlend = TweenService:GetValue(shakeElapsed / shakeInterval, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		local shake = previousShake:Lerp(nextShake, shakeBlend) * (1 - progress)

		self._SpawnOffset = CFrame.new(shake.X * SPAWN_SHAKE_DISTANCE, -SPAWN_DEPTH * self._Scale * (1 - rise), shake.Y * SPAWN_SHAKE_DISTANCE)
			* CFrame.Angles(-shake.Y * SPAWN_SHAKE_ANGLE, 0, shake.X * SPAWN_SHAKE_ANGLE)

		if progress >= 1 then
			self._SpawnOffset = CFrame.identity
			self._Trove:Remove(connection)
		end

		self:_ApplyDisplayCFrame()
	end)
	self._Trove:Add(connection)
end

function Dirt:_AnimateHit()
	if self._HitConnection then
		self._Trove:Remove(self._HitConnection)
	end

	local random = Random.new()
	local part = Instance.new("Part")
	part.Color = Color3.fromRGB(106, 57, 9)
	part.Material = Enum.Material.Snow
	part.MaterialVariant = "Studs"
	UtilFunctions.DoFlyingDebris(part, Vector3.one * 0.5, {
		Count = math.random(4, 6),
		ExplosionOrigin = self._CFrame.Position + Vector3.new(0, 1, 0),
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
	newDirtDigParticles.CFrame = self._CFrame + Vector3.new(0, 1, 0)
	UtilFunctions.DisableParticles(newDirtDigParticles)
	newDirtDigParticles.Parent = Workspace

	local _, longestEmitTime = UtilFunctions.GetLongestEmitter(newDirtDigParticles)
	Debris:AddItem(newDirtDigParticles, longestEmitTime)

	UtilFunctions.EmitParticles(newDirtDigParticles)
	UtilFunctions.PlaySoundAtLocation(DigSound, self._CFrame)

	self._HitElapsed = 0
	local shakeElapsed = 0
	local shakeInterval = math.pi / HIT_SHAKE_SPEED
	local previousShake = Vector2.zero
	local random = Random.new()
	local angle = random:NextNumber(0, math.pi * 2)
	local nextShake = Vector2.new(math.cos(angle), math.sin(angle)) * random:NextNumber(0.5, 1)
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		self._HitElapsed = math.min(self._HitElapsed + dt, HIT_DURATION)
		shakeElapsed += dt
		while shakeElapsed >= shakeInterval do
			shakeElapsed -= shakeInterval
			previousShake = nextShake
			angle = random:NextNumber(0, math.pi * 2)
			nextShake = Vector2.new(math.cos(angle), math.sin(angle)) * random:NextNumber(0.5, 1)
		end

		local progress = self._HitElapsed / HIT_DURATION
		local shakeBlend = TweenService:GetValue(shakeElapsed / shakeInterval, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		local shake = previousShake:Lerp(nextShake, shakeBlend) * (1 - progress)
		local dip = math.sin(progress * math.pi) * HIT_DIP_DISTANCE

		self._HitOffset = CFrame.new(shake.X * HIT_SHAKE_DISTANCE, -dip, shake.Y * HIT_SHAKE_DISTANCE)
			* CFrame.Angles(-shake.Y * HIT_SHAKE_ANGLE, 0, shake.X * HIT_SHAKE_ANGLE)

		if progress >= 1 then
			self._HitOffset = CFrame.identity
			self._HitElapsed = nil
			self._HitConnection = nil
			self._Trove:Remove(connection)
		end

		self:_ApplyDisplayCFrame()
	end)
	self._HitConnection = self._Trove:Add(connection)
end

function Dirt:_ShowDamage(amount)
	if not self._Model then return end

	local boundingCFrame, boundingSize = self._Model:GetBoundingBox()
	local halfSize = boundingSize * 0.35
	local random = Random.new()
	local position = boundingCFrame:PointToWorldSpace(Vector3.new(
		random:NextNumber(-halfSize.X, halfSize.X),
		random:NextNumber(-halfSize.Y, halfSize.Y),
		random:NextNumber(-halfSize.Z, halfSize.Z)
	))

	local anchor = Instance.new("Part")
	anchor.Name = "DirtDamagePopup"
	anchor.Size = Vector3.one * 0.1
	anchor.Position = position
	anchor.Anchored = true
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Parent = Workspace

	local gui = DamageGui:Clone()
	local fullSize = gui.Size
	gui.Size = UDim2.fromScale(0, 0)
	gui.AmountText.Text = "-" .. BigNumbers.GetNumberDisplay(amount)
	gui.Adornee = anchor
	gui.AlwaysOnTop = true
	gui.Parent = anchor

	local totalTime = DAMAGE_GUI_GROW_TIME + DAMAGE_GUI_HOLD_TIME + DAMAGE_GUI_SHRINK_TIME
	local riseTween = TweenService:Create(anchor, TweenInfo.new(totalTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = position + Vector3.new(0, DAMAGE_GUI_RISE, 0)
	})
	local growTween = TweenService:Create(gui, TweenInfo.new(DAMAGE_GUI_GROW_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = fullSize
	})
	local shrinkTween = TweenService:Create(gui, TweenInfo.new(DAMAGE_GUI_SHRINK_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.fromScale(0, 0)
	})

	Debris:AddItem(anchor, totalTime + 1)
	growTween.Completed:Connect(function(playbackState)
		if playbackState ~= Enum.PlaybackState.Completed then return end
		task.delay(DAMAGE_GUI_HOLD_TIME, function()
			shrinkTween:Play()
		end)
	end)
	shrinkTween.Completed:Connect(function()
		anchor:Destroy()
	end)

	riseTween:Play()
	growTween:Play()
end

function Dirt:_SetupDirtGui()
	local dirtInfo = DirtDef.GetDirtInfo(self._DirtId)
	if not dirtInfo then return end

	local _, size = StageOneModel:GetBoundingBox()
	local scaledSize = size * self._Scale
	local difference = scaledSize - size

	local newDirtGui = DirtGui:Clone()
	newDirtGui.StudsOffsetWorldSpace = newDirtGui.StudsOffsetWorldSpace + Vector3.new(0, difference.Y, 0)
	newDirtGui.Adornee = self._RootPart
	newDirtGui.Parent = Player:WaitForChild("PlayerGui")
	self._Trove:Add(newDirtGui)

	newDirtGui.RarityText.Text = dirtInfo.Rarity
	newDirtGui.RarityText.TextColor3 = Constants.RarityColors[dirtInfo.Rarity]
	newDirtGui.SizeText.Text = string.format("Size: %0.1fx", self._Scale)

	self._DirtGui = newDirtGui

	self:_UpdateDirtGui()
end

function Dirt:_UpdateDirtGui()
	if not self._DirtGui then return end

	local progressBar = self._DirtGui.ProgressBar
	local amountText = progressBar.AmountText
	local bar = progressBar.Bar

	amountText.Text = string.format("%s / %s", BigNumbers.GetNumberDisplay(self._Health), BigNumbers.GetNumberDisplay(self._TotalHealth))

	local progress = math.clamp(self._Health / self._TotalHealth, 0, 1)
	local oldSize = bar.Size

	local tweenInfo = TweenInfo.new(0.2)
	local tween = TweenService:Create(bar, tweenInfo, {
		Size = UDim2.new(progress, 0, oldSize.Y.Scale, oldSize.Y.Offset)
	})
	tween:Play()
end

function Dirt:Update(replicationData)
	self._DirtId = replicationData.DirtId
	local totalHealth = math.max(1, replicationData.TotalHealth)
	local health = math.clamp(replicationData.Health, 0, totalHealth)
	local damage = self._Health - health

	self._TotalHealth = totalHealth
	self._Health = health

	local stage = math.clamp(math.floor((1 - health / totalHealth) * #StageModels) + 1, 1, #StageModels)

	if stage ~= self._Stage then
		local model = StageModels[stage]:Clone()
		model:ScaleTo(self._Scale)
		model.Name = "Dirt_" .. self._Guid
		model:SetAttribute("DirtGuid", self._Guid)
		model:SetAttribute("DirtId", self._DirtId)

		UtilFunctions.AnchorAllDescendants(model, true)
		UtilFunctions.CanCollideAllDescendants(model, false)
		UtilFunctions.CanQueryAllDescendants(model, true)

		model:PivotTo(self._DisplayCFrame)
		model.Parent = DirtFolder

		self._Trove:Remove(self._Model)

		self._Model = model
		self._Stage = stage

		self._Trove:Add(self._Model)
	end

	self:_UpdateDirtGui()
	if damage > 0 then
		self:_ShowDamage(damage)
		local predictionId = replicationData.LastHitPredictionId
		-- The matching local dig already started its shake before this update arrived.
		if replicationData.LastHitUserId == Player.UserId and self._PredictedHits[predictionId] then
			self._PredictedHits[predictionId] = nil
		else
			self:_AnimateHit()
		end
	end
end

function Dirt:Destroy()
	if self._Destroyed then return end
	self._Destroyed = true

	self._Model = nil

	self._Trove:Clean()
end

return Dirt
