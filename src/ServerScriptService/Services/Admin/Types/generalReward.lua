local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local ItemDef = require(ReplicatedConfigs:WaitForChild("ItemDef"))

local rewardTypes = {}

table.insert(rewardTypes, PlayerStatsEnum.Cash)

for itemId in pairs(ItemDef.GetAllItems()) do
	table.insert(rewardTypes, itemId)
end

return function (registry)
	registry:RegisterType("rewardType", registry.Cmdr.Util.MakeEnumType("RewardType", rewardTypes))
end