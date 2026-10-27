local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))

local CodesDef = {}

-- Each table needs
-- Code (a string code that the player must know)
-- Rewards (a table of rewards)
-- ExpiryTime (optional field to make a code expire after a certain UNIX time)
CodesDef.Table = {
	["Launch"] = {
		Code = "Launch",
		Rewards = {
			[PlayerStatsEnum.Cash] = 5_000,
			[PlayerStatsEnum.DigPower] = 100
		},
	}
}

function CodesDef.GetCodeInfoFromCode(code)
	for _, info in pairs(CodesDef.Table) do
		if string.lower(info.Code) == string.lower(code) then
			return info
		end
	end
end

return CodesDef