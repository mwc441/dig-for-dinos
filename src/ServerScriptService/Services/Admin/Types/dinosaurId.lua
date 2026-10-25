local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DinosaurDef = require(ReplicatedStorage:WaitForChild("ReplicatedConfigs"):WaitForChild("DinosaurDef"))

local dinosaurIds = {}
for dinosaurId in pairs(DinosaurDef.GetAllDinosaurs()) do
	table.insert(dinosaurIds, dinosaurId)
end
table.sort(dinosaurIds)

return function(registry)
	registry:RegisterType("dinosaurId", registry.Cmdr.Util.MakeEnumType("Dinosaur ID", dinosaurIds))
end
