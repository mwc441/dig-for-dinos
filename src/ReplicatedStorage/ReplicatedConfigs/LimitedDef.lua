local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local LimitedsEnum = require(Enums:WaitForChild("Limiteds"))

local LimitedDef = {}

LimitedDef.Table = {
	-- [LimitedsEnum.Test] = {
	-- 	Limit = 10_000,
	-- 	ExpiryTime = nil
	-- }
	[LimitedsEnum.Serpent] = {
		Limit = 1_000
	}
}

function LimitedDef.GetAllLimiteds()
	return LimitedDef.Table
end

function LimitedDef.GetLimitedInfo(id)
	return LimitedDef.Table[id]
end

return LimitedDef
