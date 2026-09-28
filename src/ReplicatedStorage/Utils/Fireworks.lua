local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Particles = Assets:WaitForChild("Particles")
local Sounds = Assets:WaitForChild("Sounds")
local FireworksParticles = Particles:WaitForChild("Fireworks")
local External = ReplicatedStorage:WaitForChild("External")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local TableUtils = require(External:WaitForChild("TableUtils"))
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))

--// Sound asset used for firework explosion - swap for your own sound if you want, found this one in the toolbox just search up Fireworks at sounds
local soundId = "rbxassetid://6958700030"
--// Base colors for fireworks, you can add or remove colors here
local baseColors = {
	Color3.fromRGB(255, 49, 49), --// red
	Color3.fromRGB(255, 179, 55), --// orange
	Color3.fromRGB(255, 255, 53), --// yellow
	Color3.fromRGB(105, 255, 79), --// green
	Color3.fromRGB(90, 112, 255), --// purple
	Color3.fromRGB(70, 252, 255), --// blue
	Color3.fromRGB(193, 85, 255), --// purple light
	Color3.fromRGB(255, 169, 225) --// pink
}
local rng = Random.new()

local Fireworks = {}

function Fireworks.CloneParticle(template, color)
	if not template then return nil end
	local clone = template:Clone()
	if clone:IsA("ParticleEmitter") then
		clone.Color = ColorSequence.new(color)
	end
	return clone
end

function Fireworks.FireSingle(origin, color)
	local part = Instance.new("Part")
	part.Size = Vector3.new(0.5, 0.5, 0.5) --// part size customizable here
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.CFrame = origin
	part.Name = "firework"
	part.Parent = workspace

	--// Trail particle
	local trail = Fireworks.CloneParticle(FireworksParticles:FindFirstChild("Trail"), color)
	trail.Parent = part
	trail.Enabled = true

	--// Spec particle for sparkle effect
	local spec = FireworksParticles:FindFirstChild("Spec"):Clone()
	spec.Parent = part
	spec.Enabled = true
	spec.Color = ColorSequence.new(Color3.new(1, 1, 1))
	spec.Size = NumberSequence.new(0.1) --// size tweak here 0.1
	spec.Speed = NumberRange.new(0.5, 1) --// speed tweak here 0.5, 1
	spec.Acceleration = Vector3.new(0, -9.8 * 3, 0) --// gravity effect 0, -9.8 * 3, 0
	spec.Rate = 30 --// emission rate 30
	spec.EmissionDirection = Enum.NormalId.Top
	spec.Lifetime = NumberRange.new(0.5, 1) --// lifetime of particles 0.5, 1 in this case lol
	spec.LightInfluence = 0
	spec.LockedToPart = true

	--// Firework flight path tweaks - angle range and rise height
	local angleX = rng:NextNumber(-7, 7)
	local angleZ = rng:NextNumber(-7, 7)
	local rise = rng:NextNumber(7, 9)
	local target = origin + Vector3.new(angleX, rise, angleZ)

	--// Tween duration depends on rise height, adjustable divisor to speed/slow flight
	local tweenDur = 0.75
	local tween = TweenService:Create(part, TweenInfo.new(tweenDur, Enum.EasingStyle.Quad), {
		CFrame = target
	})

	tween:Play()
	tween.Completed:Wait()

	--// Fade duration for Trail and Spec 0,3
	local fadeDuration = 0.3

	--// Explosion and Sparks effects
	local explosion = Fireworks.CloneParticle(FireworksParticles:FindFirstChild("Explosion"), color)
	explosion.Parent = part
	explosion:Emit(rng:NextInteger(60, 100))

	local sparks = Fireworks.CloneParticle(FireworksParticles:FindFirstChild("Sparks"), color)
	sparks.Parent = part
	sparks:Emit(rng:NextInteger(40, 80))

	task.delay(0.3, function()
		if sparks then sparks.Enabled = false end
	end)

	--// Optional Sparkle and Flare effects can be kept named like this and will still work even if not present
	if FireworksParticles:FindFirstChild("Sparkle") then
		local sparkle = Fireworks.CloneParticle(FireworksParticles:FindFirstChild("Sparkle"), color)
		sparkle.Parent = part
		sparkle:Emit(rng:NextInteger(20, 40))
	end

	if FireworksParticles:FindFirstChild("Flare") then
		local flare = Fireworks.CloneParticle(FireworksParticles:FindFirstChild("Flare"), color)
		flare.Parent = part
		flare:Emit(rng:NextInteger(10, 30))
	end

	local startTime = tick()
	while tick() - startTime < fadeDuration do
		local progress = (tick() - startTime) / fadeDuration
		local alpha = NumberSequence.new(progress)
		if trail then trail.Transparency = alpha end
		if spec then spec.Transparency = alpha end
		task.wait()
	end

	if trail then trail.Enabled = false end
	if spec then spec.Enabled = false end

	--// Cleanup firework
	task.delay(4, function()
		if part then part:Destroy() end
	end)
end

function Fireworks.LaunchFireworks(origin : CFrame)
	local count = rng:NextInteger(6, 9) --// number of fireworks per launch 6,  9
	local usedColors = TableUtils.Shuffle(baseColors)
	for i = 1, count do
		local color = usedColors[i] or baseColors[rng:NextInteger(1, #baseColors)]
		task.delay((i - 1) * 0.07, function()
			Fireworks.FireSingle(origin, color)
		end)
	end

	--// Firework sound delay can be configured the 0.5
	task.delay(0, function()
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = 1
		sound.SoundGroup = Sounds.SFX

		UtilFunctions.PlaySoundAtLocation(sound, origin)
	end)
end

return Fireworks