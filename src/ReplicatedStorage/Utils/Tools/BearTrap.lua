local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local BearTrapSound = Sounds:WaitForChild("BearTrap")
local BearTrapPlacedSound = Sounds:WaitForChild("BearTrapPlaced")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local External = ReplicatedStorage:WaitForChild("External")
local Device = require(External:WaitForChild("Device"))
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local Ragdoll = require(Utils:WaitForChild("Ragdoll"))

local PLACE_COOLDOWN = 60
local MAX_PLACE_DISTANCE = 50
local TRAP_LIFETIME = 60
local RAGDOLL_DURATION = 3
local RAY_DISTANCE = 250

local LastPlaced = setmetatable({}, { __mode = "k" })
local RagdollTokens = setmetatable({}, { __mode = "k" })

local BearTrap = {}

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
	local trapFolder = Workspace:FindFirstChild("BearTraps")
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
		if targetPosition and (os.clock() >= nextPlaceAt) then
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
		if waitingForServer or os.clock() < nextPlaceAt then return end
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

	local trapAsset = Assets:FindFirstChild("BearTrap")
	if not trapAsset or not trapAsset:IsA("Model") then return false end
	local trapFolder = Workspace:FindFirstChild("BearTraps")
	local groundHit = getGroundHit(player, targetPosition, trapFolder, toolService:GetCharacters())
	if not groundHit then return false end

	local trap = trapAsset:Clone()
	local boxCFrame, boxSize = trap:GetBoundingBox()
	local boxToPivot = boxCFrame:ToObjectSpace(trap:GetPivot())
	trap:PivotTo(CFrame.new(groundHit.Position + Vector3.new(0, boxSize.Y * 0.5, 0)) * boxToPivot)
	UtilFunctions.AnchorAllDescendants(trap, true)
	UtilFunctions.CanCollideAllDescendants(trap, false)
	UtilFunctions.CanQueryAllDescendants(trap, false)
	UtilFunctions.CanTouchAllDescendants(trap, false)

	local trigger = trap.HitBox
	trigger.CanTouch = true

	trap:SetAttribute("OwnerUserId", player.UserId)
	local triggered = false
	trigger.Touched:Connect(function(part)
		if triggered then return end
		local character = part.Parent
		if not character or not character:IsA("Model") then return end
		local victim = Players:GetPlayerFromCharacter(character)
		if not victim or victim.UserId == player.UserId then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end

		triggered = true
		trap:Destroy()
		ragdollVictim(victim, character, toolService)
		UtilFunctions.PlaySoundAtLocation(BearTrapSound, trigger.CFrame)
	end)

	if not trapFolder then
		trapFolder = Instance.new("Folder")
		trapFolder.Name = "BearTraps"
		trapFolder.Parent = Workspace
	end
	LastPlaced[player] = now
	trap.Parent = trapFolder

	task.delay(TRAP_LIFETIME, function()
		trap:Destroy()
		LastPlaced[player] = nil
	end)

	return true
end

return BearTrap
