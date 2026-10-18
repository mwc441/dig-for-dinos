local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local WeatherAssets = Assets:WaitForChild("Weather")
local LightingConfigs = WeatherAssets:WaitForChild("Lighting")
local Particles = WeatherAssets:WaitForChild("Particles")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local CameraModel = require(Utils:WaitForChild("CameraModel"))

local Weather = {}
Weather.__index = Weather

function Weather.new(weatherId)
	local self = setmetatable({}, Weather)
	local lightingConfig = LightingConfigs:FindFirstChild(weatherId)

	if lightingConfig and lightingConfig:IsA("Configuration") then
		self._DefaultLightingChildren = Lighting:GetChildren()
		for _, child in self._DefaultLightingChildren do
			child.Parent = ReplicatedStorage
		end

		self._WeatherLightingChildren = {}
		for _, child in lightingConfig:GetChildren() do
			local clone = child:Clone()
			clone.Parent = Lighting
			table.insert(self._WeatherLightingChildren, clone)
		end
	else
		warn(`Missing lighting configuration for weather {weatherId}`)
	end

	local template = Particles:FindFirstChild(weatherId)

	if not template or not template:IsA("BasePart") then
		warn(`Missing particle part for weather {weatherId}`)
		return self
	end

	local particlePart = template:Clone()
	particlePart.Anchored = true
	particlePart.CanCollide = false
	particlePart.CanTouch = false
	particlePart.CanQuery = false
	particlePart.Transparency = 1
	particlePart.Parent = Workspace

	self._ParticlePart = particlePart
	self._CameraModel = CameraModel.new(particlePart, CFrame.new())

	return self
end

function Weather:Destroy()
	if self._WeatherLightingChildren then
		for _, child in self._WeatherLightingChildren do
			child:Destroy()
		end
		self._WeatherLightingChildren = nil
	end

	if self._DefaultLightingChildren then
		for _, child in self._DefaultLightingChildren do
			pcall(function()
				child.Parent = Lighting
			end)
		end
		self._DefaultLightingChildren = nil
	end

	if self._CameraModel then
		self._CameraModel:Destroy()
		self._CameraModel = nil
	end

	if self._ParticlePart then
		self._ParticlePart:Destroy()
		self._ParticlePart = nil
	end
end

return Weather
