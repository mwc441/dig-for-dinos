local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Knit = require(External:WaitForChild("Knit"))

local ConditionsService = {
	Name = "ConditionsService",
	Client = {}
}

function ConditionsService:MeetsConditions(player, conditions)
	conditions = conditions or {}

	local success = true
	for _, conditionTable in pairs(conditions) do
		local conditionId = conditionTable[1]

		-- if conditionId == "UpgradeUnlocked" then
		-- 	local upgradeId = conditionTable[2]
		-- 	local levelRequirement = conditionTable[3] or 1

		-- 	local upgradeLevel = self._UpgradeService:GetUpgradeLevelForPlayer(player, upgradeId) or 0
		-- 	if upgradeLevel < levelRequirement then
		-- 		success = false
		-- 		break
		-- 	end
		-- end
	end

	return success
end

return ConditionsService