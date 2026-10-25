local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LimitedDef = {}

LimitedDef.Table = {
	-- [LimitedsEnum.Test] = {
	-- 	Limit = 10_000,
	-- 	ExpiryTime = nil
	-- }
}

function LimitedDef.GetAllLimiteds()
	return LimitedDef.Table
end

function LimitedDef.GetLimitedInfo(id)
	return LimitedDef.Table[id]
end

return LimitedDef
