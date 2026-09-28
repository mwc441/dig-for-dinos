local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local ItemDef = require(ReplicatedConfigs:WaitForChild("ItemDef"))

local rewardTypes = {}
for itemId in pairs(ItemDef.GetAllItems()) do
	table.insert(rewardTypes, itemId)
end

table.insert(rewardTypes, PlayerStatsEnum.Cash)

return function (registry)
	registry:RegisterType("rewardType", registry.Cmdr.Util.MakeEnumType("RewardType", rewardTypes))
end