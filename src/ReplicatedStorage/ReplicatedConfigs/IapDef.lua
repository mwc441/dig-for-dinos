local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local IapTypesEnum = require(Enums:WaitForChild("IapTypes"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local IapsEnum = require(Enums:WaitForChild("Iaps"))

local IapDef = {}

-- Iap's only need an Ids field if there is a robux purchase
-- associated with it

-- MaxPurchases is optional, limits user from purchasing past a certain amount
-- Giftable field is optional, boolean declaring if an iap is giftable to another user

-- If an Iap is a devproduct, it requires a Rewards table, it can be an empty table

IapDef.Table = {
	-- DEV PRODUCTS
	[IapsEnum.SkipRebirth] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3716349307
		},
		Name = "Skip Rebirth",
		Description = "",
		Rewards = {
			["SkipRebirth"] = true
		},
		Giftable = true
	}

	-- GAMEPASSES
	-- [IapsEnum.Bricks2xGamepass] = {
	-- 	Ids = {
	-- 		[IapTypesEnum.DevProduct] = 3708793171
	-- 	},
	-- 	Name = "2x Bricks",
	-- 	Description = "",
	-- 	Rewards = {},
	-- 	Giftable = true,
	-- 	MaxPurchases = 1
	-- }
}

-- Table that indicates the order of purchase of a dev product
-- and only allows them to be purchased in their given order.
-- Each ordering is its own table
IapDef.OrderOfPurchase = {
	{ IapsEnum.Speed3x, IapsEnum.Speed4x }
}

function IapDef.GetAllIaps()
	return IapDef.Table
end

function IapDef.GetIapInfo(iapId)
	return IapDef.Table[iapId]
end

function IapDef.GetIapInfoFromProductId(productId)
	for iapId, iapInfo in pairs(IapDef.Table) do
		local ids = iapInfo.Ids or {}

		for _, id in pairs(ids) do
			if id == productId then
				return iapInfo, iapId
			end
		end
	end
end

function IapDef.GetOrderOfPurchaseTable(iapId)
	for _, orderTable in pairs(IapDef.OrderOfPurchase) do
		if table.find(orderTable, iapId) then
			return orderTable
		end
	end
end

return IapDef
