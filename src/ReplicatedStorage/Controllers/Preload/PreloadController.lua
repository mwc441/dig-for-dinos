local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local External = ReplicatedStorage:WaitForChild("External")
local Knit = require(External:WaitForChild("Knit"))

local PreloadController = {
	Name = "PreloadController",
}

function PreloadController:KnitStart()
	repeat task.wait() until game:IsLoaded()

	local assets = ReplicatedStorage.Assets

	local toLoad = { assets.Dirt, assets.BonePiles, assets.Sounds, assets.Animations, assets.ClientAssets, assets.Particles }
	for _, descendant in pairs(Player:WaitForChild("PlayerGui"):GetDescendants()) do
		table.insert(toLoad, descendant)
	end

	ContentProvider:PreloadAsync(toLoad)
end

return PreloadController