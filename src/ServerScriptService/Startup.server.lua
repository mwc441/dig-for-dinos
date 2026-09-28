local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local Services = ServerScriptService:WaitForChild("Services")
local Components = ServerScriptService:WaitForChild("Components")
local Knit = require(External:WaitForChild("Knit"))

local function AddServicesCustom(parent: Instance)
    -- For deep scan, switch GetChildren() to GetDescendants()
    for _, v in parent:GetDescendants() do
        -- Only match on instances that are ModuleScripts and names that end with "Service":
        if v:IsA("ModuleScript") and v.Name:match("Service$") then
            local service = require(v) -- Load the service module
            Knit.CreateService(service) -- Add the service into Knit
        end
    end
end

AddServicesCustom(Services)

Knit.Start():andThen(function()
	for _, component in pairs(Components:GetDescendants()) do
		if component:IsA("ModuleScript") then
			require(component)
		end
	end
end)