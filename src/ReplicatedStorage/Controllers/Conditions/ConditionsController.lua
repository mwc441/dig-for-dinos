local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Knit = require(External:WaitForChild("Knit"))

local ConditionsController = {
	Name = "ConditionsController"
}

function ConditionsController:KnitStart()
end

function ConditionsController:MeetsConditions(conditions)
	conditions = conditions or {}

	local success = true
	for _, conditionTable in pairs(conditions) do
		local conditionId = conditionTable[1]

		-- if conditionId == "UpgradeUnlocked" then
		-- 	local upgradeId = conditionTable[2]
		-- 	local levelRequirement = conditionTable[3] or 1

		-- 	local upgradeLevel = self._UpgradeController:GetUpgradeLevel(upgradeId) or 0
		-- 	if upgradeLevel < levelRequirement then
		-- 		success = false
		-- 		break
		-- 	end
		-- end
	end

	return success
end

return ConditionsController