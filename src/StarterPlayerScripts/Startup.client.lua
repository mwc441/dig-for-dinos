local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Controllers = ReplicatedStorage:WaitForChild("Controllers")
local Components = ReplicatedStorage:WaitForChild("Components")
local Knit = require(External:WaitForChild("Knit"))

local function AddController(v : ModuleScript)
	-- Only match on instances that are ModuleScripts and names that end with "Controller":
	if v:IsA("ModuleScript") and v.Name:match("Controller$") then
		local controller = require(v) -- Load the service module
		Knit.CreateController(controller) -- Add the service into Knit
	end
end

local function AddControllersCustom(parent: Instance)
    for _, v in parent:GetDescendants() do
		AddController(v)
    end
end

repeat task.wait() until game:IsLoaded()

AddControllersCustom(Controllers)

Knit.Start():andThen(function()
	for _, component in pairs(Components:GetDescendants()) do
		if component:IsA("ModuleScript") then
			require(component)
		end
	end
end)