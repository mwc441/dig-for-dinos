local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local BearTrapSound = Sounds:WaitForChild("BearTrap")
local BearTrapPlacedSound = Sounds:WaitForChild("BearTrapPlaced")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Device = require(External:WaitForChild("Device"))
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local Ragdoll = require(Utils:WaitForChild("Ragdoll"))
local UpgradesDef = require(ReplicatedConfigs:WaitForChild("UpgradesDef"))

local PLACE_COOLDOWN = 0.5
local MAX_PLACE_DISTANCE = 50
local TRAP_LIFETIME = 60
local RAGDOLL_DURATION = 5
local RAY_DISTANCE = 250
local TRAP_UPGRADE_ID = "BearTrapUpgrade"
local PICKUP_DISTANCE = 10

local LastPlaced = setmetatable({}, { __mode = "k" })
local RagdollTokens = setmetatable({}, { __mode = "k" })

local function getActiveTrapCount(player, trapFolder)
	if not trapFolder then return 0 end

	local count = 0
	for _, trap in ipairs(trapFolder:GetChildren()) do
		if trap:GetAttribute("OwnerUserId") == player.UserId then
			count += 1
		end
	end
	return count
end

local BearTrap = {}
local ServerTrapFolder
local PickupRemote
if RunService:IsServer() then
	ServerTrapFolder = Workspace:FindFirstChild("_BearTraps")
	if not ServerTrapFolder then
		ServerTrapFolder = Instance.new("Folder")
		ServerTrapFolder.Name = "_BearTraps"
		ServerTrapFolder.Parent = Workspace
	end

	PickupRemote = Instance.new("RemoteEvent")
	PickupRemote.Name = "PickupBearTrap"
	PickupRemote.Parent = script
	PickupRemote.OnServerEvent:Connect(function(player, trap)
		if typeof(trap) ~= "Instance" or not trap:IsA("Model") or trap.Parent ~= ServerTrapFolder then return end
		if trap:GetAttribute("OwnerUserId") ~= player.UserId then return end

		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local hitBox = trap:FindFirstChild("HitBox")
		if not rootPart or not humanoid or humanoid.Health <= 0 or not hitBox or not hitBox:IsA("BasePart") then return end
		if (rootPart.Position - hitBox.Position).Magnitude > PICKUP_DISTANCE + 2 then return end

		trap:Destroy()
	end)

	Players.PlayerRemoving:Connect(function(player)
		LastPlaced[player] = nil

		for _, trap in ipairs(ServerTrapFolder:GetChildren()) do
			if trap:GetAttribute("OwnerUserId") == player.UserId then
				trap:Destroy()
			end
		end
	end)
else
	PickupRemote = script:WaitForChild("PickupBearTrap")
end

local function isFiniteVector3(value)
	return typeof(value) == "Vector3"
		and value.X == value.X and math.abs(value.X) < 1000000
		and value.Y == value.Y and math.abs(value.Y) < 1000000
		and value.Z == value.Z and math.abs(value.Z) < 1000000
end

local function getClientTargetPosition()
	local player = Players.LocalPlayer
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if not rootPart or not camera then return end

	local screenPosition
	local deviceType = Device.GetUserDevice()
	if deviceType == "Mobile" or deviceType == "Controller" then
		local viewportSize = camera.ViewportSize
		screenPosition = Vector2.new(viewportSize.X * 0.5, viewportSize.Y * 0.4)
	else
		screenPosition = UserInputService:GetMouseLocation()
	end

	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclusions = {}
	local trapFolder = Workspace:FindFirstChild("_BearTraps")
	if trapFolder then
		table.insert(exclusions, trapFolder)
	end
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer.Character then
			table.insert(exclusions, otherPlayer.Character)
		end
	end
	params.FilterDescendantsInstances = exclusions
	local result = Workspace:Raycast(ray.Origin, ray.Direction * RAY_DISTANCE, params)
	if not result or result.Normal.Y < 0.65 then return end
	if (result.Position - rootPart.Position).Magnitude > MAX_PLACE_DISTANCE then return end
	return result.Position
end

local nextPlaceAt = 0

function BearTrap:ClientEquipped(tool, toolController)
	local player = Players.LocalPlayer
	local upgradeController = require(ReplicatedStorage.Controllers.Upgrades.UpgradeController)
	local trapFolder = Workspace:WaitForChild("_BearTraps")
	local gui = Assets:WaitForChild("BearTrapToolGui"):Clone()
	local handle = tool:WaitForChild("Handle")
	gui.Adornee = handle
	gui.Parent = handle

	local function getRemainingTrapCount()
		local level = upgradeController:GetUpgradeLevel(TRAP_UPGRADE_ID)
		local limit = UpgradesDef.GetAmountForUpgrade(TRAP_UPGRADE_ID, level)
		return math.max(0, limit - getActiveTrapCount(player, trapFolder))
	end

	local function updateAmount()
		gui.AmountText.Text = string.format("%dx", getRemainingTrapCount())
	end

	local trapAddedConnection = trapFolder.ChildAdded:Connect(updateAmount)
	local trapRemovedConnection = trapFolder.ChildRemoved:Connect(updateAmount)
	local upgradeConnection = upgradeController.UpgradesUpdated:Connect(updateAmount)
	updateAmount()

	local function canPlaceMoreTraps()
		return getRemainingTrapCount() > 0
	end

	local ghost = Assets:WaitForChild("BearTrap"):Clone()
	ghost.Name = "BearTrapGhost"
	local boxCFrame, boxSize = ghost:GetBoundingBox()
	local boxToPivot = boxCFrame:ToObjectSpace(ghost:GetPivot())
	UtilFunctions.AnchorAllDescendants(ghost, true)
	UtilFunctions.CanCollideAllDescendants(ghost, false)
	UtilFunctions.CanQueryAllDescendants(ghost, false)
	UtilFunctions.CastShadowAllDescendants(ghost, false)
	UtilFunctions.SetTransparencyAllDescendants(ghost, 0.5, true)

	local previewConnection = RunService.RenderStepped:Connect(function()
		local targetPosition = getClientTargetPosition()
		if targetPosition and os.clock() >= nextPlaceAt and canPlaceMoreTraps() then
			ghost:PivotTo(CFrame.new(targetPosition + Vector3.new(0, boxSize.Y * 0.5, 0)) * boxToPivot)
			if ghost.Parent ~= Workspace then
				ghost.Parent = Workspace
			end
		elseif ghost.Parent then
			ghost.Parent = ReplicatedStorage
		end
	end)

	local waitingForServer = false

	local connection = tool.Activated:Connect(function()
		if waitingForServer or os.clock() < nextPlaceAt or not canPlaceMoreTraps() then return end
		local targetPosition = getClientTargetPosition()
		if not targetPosition then return end

		waitingForServer = true
		local request = toolController:ActivateTool(tool, targetPosition)
		if not request then
			waitingForServer = false
			return
		end
		request:andThen(function(placed)
			waitingForServer = false
			if placed then
				nextPlaceAt = os.clock() + PLACE_COOLDOWN
				UtilFunctions.PlayCopyOfSound(BearTrapPlacedSound)
			end
		end):catch(function()
			waitingForServer = false
		end)
	end)

	return function()
		connection:Disconnect()
		previewConnection:Disconnect()
		trapAddedConnection:Disconnect()
		trapRemovedConnection:Disconnect()
		upgradeConnection:Disconnect()
		gui:Destroy()
		ghost:Destroy()
	end
end

function BearTrap:ServerEquipped(player, tool)
end

local function getGroundHit(player, targetPosition, trapFolder, characters)
	local character = characters[player]
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid or humanoid.Health <= 0 then return end
	if (targetPosition - rootPart.Position).Magnitude > MAX_PLACE_DISTANCE then return end

	local exclusions = { trapFolder }
	for _, otherCharacter in pairs(characters) do
		table.insert(exclusions, otherCharacter)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions
	local hit = Workspace:Raycast(targetPosition + Vector3.new(0, 6, 0), Vector3.new(0, -18, 0), params)
	if not hit or hit.Normal.Y < 0.65 then return end
	if (hit.Position - targetPosition).Magnitude > 6 then return end
	if (hit.Position - rootPart.Position).Magnitude > MAX_PLACE_DISTANCE then return end
	return hit
end

local function ragdollVictim(victim, character, toolService)
	local token = {}
	RagdollTokens[victim] = token
	Ragdoll:RagdollCharacter(victim, character)
	task.delay(RAGDOLL_DURATION, function()
		if RagdollTokens[victim] ~= token then return end
		RagdollTokens[victim] = nil
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if victim.Parent == Players and toolService:GetCharacters()[victim] == character and humanoid and humanoid.Health > 0 then
			Ragdoll:UnragdollCharacter(victim)
		end
	end)
end

function BearTrap:ServerActivated(player, tool, toolService, targetPosition)
	if not isFiniteVector3(targetPosition) then return false end
	local now = os.clock()
	if LastPlaced[player] and now - LastPlaced[player] < PLACE_COOLDOWN then return false end

	local upgradeService = require(ServerScriptService.Services.Upgrades.UpgradeService)
	local level = upgradeService:GetUpgradeLevelForPlayer(player, TRAP_UPGRADE_ID)
	if player.Parent ~= Players then return false end
	local limit = UpgradesDef.GetAmountForUpgrade(TRAP_UPGRADE_ID, level)
	if getActiveTrapCount(player, ServerTrapFolder) >= limit then return false end

	local trapAsset = Assets:FindFirstChild("BearTrap")
	if not trapAsset or not trapAsset:IsA("Model") then return false end
	local groundHit = getGroundHit(player, targetPosition, ServerTrapFolder, toolService:GetCharacters())
	if not groundHit then return false end

	local trap = trapAsset:Clone()
	trap.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local boxCFrame, boxSize = trap:GetBoundingBox()
	local boxToPivot = boxCFrame:ToObjectSpace(trap:GetPivot())
	trap:PivotTo(CFrame.new(groundHit.Position + Vector3.new(0, boxSize.Y * 0.5, 0)) * boxToPivot)
	UtilFunctions.AnchorAllDescendants(trap, true)
	UtilFunctions.CanCollideAllDescendants(trap, false)
	UtilFunctions.CanQueryAllDescendants(trap, false)
	UtilFunctions.CanTouchAllDescendants(trap, false)

	local trigger = trap.HitBox
	trigger.CanTouch = true

	local ownerUserId = player.UserId
	trap:SetAttribute("OwnerUserId", ownerUserId)
	local triggered = false
	trigger.Touched:Connect(function(part)
		if triggered then return end
		local character = part.Parent
		if not character or not character:IsA("Model") then return end
		local victim = Players:GetPlayerFromCharacter(character)
		if not victim or victim.UserId == ownerUserId then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end

		triggered = true
		trap:Destroy()
		ragdollVictim(victim, character, toolService)
		UtilFunctions.PlaySoundAtLocation(BearTrapSound, trigger.CFrame)
	end)

	LastPlaced[player] = now
	trap.Parent = ServerTrapFolder

	task.delay(TRAP_LIFETIME, function()
		trap:Destroy()
	end)

	return true
end

if RunService:IsClient() then
	local player = Players.LocalPlayer
	local trapFolder = Workspace:WaitForChild("_BearTraps")
	local BearTrapGui = Assets:WaitForChild("BearTrapGui")
	local trackedTraps = {}

	local function stopTrackingTrap(trap)
		local state = trackedTraps[trap]
		if not state then return end
		trackedTraps[trap] = nil

		if state.PromptConnection then state.PromptConnection:Disconnect() end
		if state.Prompt then state.Prompt:Destroy() end
		if state.MarkerGui then state.MarkerGui:Destroy() end
	end

	local setupOwnedTrap
	setupOwnedTrap = function(trap, state)
		if trackedTraps[trap] ~= state or trap.Parent ~= trapFolder or state.Prompt then return end

		local hitBox = trap:FindFirstChild("HitBox")
		if not hitBox then
			return
		end

		local prompt = UtilFunctions.CreateProximityPrompt(hitBox, {
			ObjectText = "Pick Up",
			HoldDuration = 0.5,
			MaxActivationDistance = PICKUP_DISTANCE,
			RequiresLineOfSight = false
		})

		state.Prompt = prompt
		state.PromptConnection = prompt.Triggered:Connect(function()
			if trap.Parent == trapFolder and trap:GetAttribute("OwnerUserId") == player.UserId then
				PickupRemote:FireServer(trap)
			end
		end)
		prompt.Parent = hitBox

		local markerGui = BearTrapGui:Clone()
		markerGui.Adornee = hitBox
		markerGui.Parent = hitBox
		state.MarkerGui = markerGui
	end

	local function trackTrap(trap)
		if not trap:IsA("Model") or trap.Parent ~= trapFolder or trackedTraps[trap] then return end

		local state = {}
		trackedTraps[trap] = state
		local function checkOwner()
			local ownerUserId = trap:GetAttribute("OwnerUserId")
			if ownerUserId == player.UserId then
				setupOwnedTrap(trap, state)
			elseif ownerUserId ~= nil then
				stopTrackingTrap(trap)
			end
		end

		checkOwner()
	end

	trapFolder.ChildAdded:Connect(trackTrap)
	trapFolder.ChildRemoved:Connect(stopTrackingTrap)
	for _, trap in ipairs(trapFolder:GetChildren()) do
		trackTrap(trap)
	end
end

return BearTrap
