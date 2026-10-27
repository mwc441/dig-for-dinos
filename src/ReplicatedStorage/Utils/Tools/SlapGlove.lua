local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Ragdoll = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("Ragdoll"))

local HITBOX_SIZE = Vector3.new(4, 4, 5)
local HITBOX_DURATION = 0.5
local RAGDOLL_DURATION = 1.5
local KNOCKBACK = 2.5

local LastServerSwing = setmetatable({}, { __mode = "k" })
local RagdollTokens = setmetatable({}, { __mode = "k" })
local LastClientSwing = 0

local SlapGlove = {}

local function isInSafeZone(position)
	for _, zone in ipairs(CollectionService:GetTagged("Zone2d")) do
		if zone.Name == "SafeZone" and zone:IsA("BasePart") and zone:IsDescendantOf(Workspace) then
			local localPosition = zone.CFrame:PointToObjectSpace(position)
			if math.abs(localPosition.X) <= zone.Size.X * 0.5
				and math.abs(localPosition.Z) <= zone.Size.Z * 0.5 then
				return true
			end
		end
	end
	return false
end

function SlapGlove:ClientEquipped(tool, toolController)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildWhichIsA("Animator")
	local swingTrack
	if animator then
		swingTrack = animator:LoadAnimation(tool:WaitForChild("Swing"))
		swingTrack.Priority = Enum.AnimationPriority.Action
	end

	local connection = tool.Activated:Connect(function()
		local now = os.clock()
		if now < LastClientSwing + tool.Configuration.SlapCooldown.Value then return end
		LastClientSwing = now

		if swingTrack then
			swingTrack:Play()
		end
		toolController:ActivateTool(tool)
	end)

	return function()
		connection:Disconnect()
		if swingTrack then
			swingTrack:Stop()
			swingTrack:Destroy()
		end
	end
end

local function slap(victim, ownerRootPart, tool)
	local character = victim.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return false end
	if isInSafeZone(rootPart.Position) then return false, true end

	local away = rootPart.Position - ownerRootPart.Position
	local flatAway = Vector3.new(away.X, 0, away.Z)
	if flatAway.Magnitude == 0 then return false end

	tool.Hand.Hit:Play()

	local mass = math.max(rootPart.AssemblyMass, KNOCKBACK)
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
	bodyVelocity.Velocity = flatAway.Unit * KNOCKBACK * mass + Vector3.new(0, 25, 0)
	bodyVelocity.P = 2000
	bodyVelocity.Parent = rootPart
	Debris:AddItem(bodyVelocity, 0.1)

	local token = {}
	RagdollTokens[victim] = token
	Ragdoll:RagdollCharacter(victim, character)

	task.delay(RAGDOLL_DURATION, function()
		if RagdollTokens[victim] ~= token then return end
		RagdollTokens[victim] = nil
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if victim.Parent == Players and victim.Character == character and humanoid and humanoid.Health > 0 then
			Ragdoll:UnragdollCharacter(victim)
		end
	end)
	return true
end

function SlapGlove:ServerActivated(player, tool)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid or humanoid.Health <= 0 then return false end

	local now = os.clock()
	if LastServerSwing[player] and now < LastServerSwing[player] + tool.Configuration.SlapCooldown.Value then
		return false
	end
	LastServerSwing[player] = now
	tool.Hand.Swing:Play()

	local hitbox = Instance.new("Part")
	hitbox.Name = "SlapHitbox"
	hitbox.Size = HITBOX_SIZE
	hitbox.CFrame = rootPart.CFrame * CFrame.new(0, 0, -HITBOX_SIZE.Z / 2)
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.CanQuery = false
	hitbox.Massless = true
	hitbox.Anchored = false

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hitbox
	weld.Part1 = rootPart
	weld.Parent = hitbox
	hitbox.Parent = Workspace

	local playersHit = {}
	local safeZoneWarningSent = false
	local function checkHit(part)
		local victim = Players:GetPlayerFromCharacter(part.Parent)
		if not victim or victim == player or playersHit[victim] then return end
		playersHit[victim] = true
		local hit, blockedBySafeZone = slap(victim, rootPart, tool)
		if not hit then
			playersHit[victim] = nil
		end
		if blockedBySafeZone and not safeZoneWarningSent then
			safeZoneWarningSent = true
			local rewardsService = require(ServerScriptService.Services.Rewards.RewardsService)
			rewardsService:AnnounceMessageToPlayer(player, "❌ You can't slap players in the safe zone!", Color3.fromRGB(255, 85, 85))
		end
	end

	hitbox.Touched:Connect(checkHit)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character, hitbox }
	for _, part in ipairs(Workspace:GetPartBoundsInBox(hitbox.CFrame, HITBOX_SIZE, overlapParams)) do
		checkHit(part)
	end

	Debris:AddItem(hitbox, HITBOX_DURATION)
	return true
end

return SlapGlove
