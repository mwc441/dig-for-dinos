local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MutationsEnum = require(ReplicatedStorage:WaitForChild("Enums"):WaitForChild("Mutations"))

local mutations = {}
for _, mutation in pairs(MutationsEnum) do
	table.insert(mutations, mutation)
end
table.sort(mutations)

return function(registry)
	registry:RegisterType("mutation", registry.Cmdr.Util.MakeEnumType("Mutation", mutations))
end
