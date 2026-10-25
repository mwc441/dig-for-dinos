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
			[IapTypesEnum.DevProduct] = 3716349307,
		},
		Name = "Skip Rebirth",
		Description = "",
		Rewards = {
			["SkipRebirth"] = true,
		},
		Giftable = true,
	},

	[IapsEnum.SpeedUpgrade] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3716788501,
		},
		Name = "+1 Speed Level",
		Description = "",
		Rewards = {
			["SpeedUpgrade"] = 1,
		},
		Giftable = true,
	},

	[IapsEnum.DigSpeedUpgrade] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3721998209,
		},
		Name = "+1 Dig Training Speed",
		Rewards = {
			["DigTrainingSpeedUpgrade"] = 1,
		},
		Giftable = true,
	},

	[IapsEnum.BearTrapUpgrade] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3721998742,
		},
		Name = "+1 Bear Trap Place",
		Rewards = {
			["BearTrapUpgrade"] = 1,
		},
		Giftable = true,
	},

	[IapsEnum.OfflineRewards1Hour] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3718677900,
		},
		Name = "1 Hour Offline Cash",
		Description = "",
		Rewards = {
			["OfflineRewards"] = 60 * 60,
		},
		Giftable = true,
	},

	[IapsEnum.OfflineRewards24Hours] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3718677950,
		},
		Name = "24 Hours Offline Cash",
		Description = "",
		Rewards = {
			["OfflineRewards"] = 24 * 60 * 60,
		},
		Giftable = true,
	},

	[IapsEnum.SmallCashPack] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720172717,
		},
		Name = "+10,000 Cash",
		Description = "",
		Rewards = {
			[PlayerStatsEnum.Cash] = 10_000,
		},
		Giftable = true,
	},

	[IapsEnum.MediumCashPack] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720173382,
		},
		Name = "+30,000 Cash",
		Description = "",
		Rewards = {
			[PlayerStatsEnum.Cash] = 30_000,
		},
		Giftable = true,
	},

	[IapsEnum.LargeCashPack] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720173860,
		},
		Name = "+100,000 Cash",
		Description = "",
		Rewards = {
			[PlayerStatsEnum.Cash] = 100_000,
		},
		Giftable = true,
	},

	[IapsEnum.GiantCashPack] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720174230,
		},
		Name = "+500K Cash",
		Description = "",
		Rewards = {
			[PlayerStatsEnum.Cash] = 500_000,
		},
		Giftable = true,
	},

	[IapsEnum.MassiveCashPack] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720174614,
		},
		Name = "5M Cash",
		Description = "",
		Rewards = {
			[PlayerStatsEnum.Cash] = 5_000_000,
		},
		Giftable = true,
	},

	[IapsEnum.SmallDigPack] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720199883,
		},
		Name = "+10,000 Dig",
		Description = "",
		Rewards = {
			[PlayerStatsEnum.DigPower] = 10_000,
		},
		Giftable = true,
	},

	[IapsEnum.MediumDigPack] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720200203,
		},
		Name = "+30,000 Dig",
		Description = "",
		Rewards = {
			[PlayerStatsEnum.DigPower] = 30_000,
		},
		Giftable = true,
	},

	[IapsEnum.LargeDigPack] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720200499,
		},
		Name = "+100,000 Dig",
		Description = "",
		Rewards = {
			[PlayerStatsEnum.DigPower] = 100_000,
		},
		Giftable = true,
	},

	[IapsEnum.GiantDigPack] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720200732,
		},
		Name = "+500K Dig",
		Description = "",
		Rewards = {
			[PlayerStatsEnum.DigPower] = 500_000,
		},
		Giftable = true,
	},

	[IapsEnum.MassiveDigPack] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720200968,
		},
		Name = "+5M Dig",
		Description = "",
		Rewards = {
			[PlayerStatsEnum.DigPower] = 5_000_000,
		},
		Giftable = true,
	},

	[IapsEnum.ServerLuck1] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3722351970
		},
		Name = "Server Luck 1",
		Description = "",
		Rewards = {
			["ServerLuck"] = 1
		},
		Giftable = false,
		PaidRandom = true
	},

	[IapsEnum.ServerLuck2] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3722352081
		},
		Name = "Server Luck 2",
		Description = "",
		Rewards = {
			["ServerLuck"] = 2
		},
		Giftable = false,
		PaidRandom = true
	},

	[IapsEnum.ServerLuck3] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3722352174
		},
		Name = "Server Luck 3",
		Description = "",
		Rewards = {
			["ServerLuck"] = 3
		},
		Giftable = false,
		PaidRandom = true
	},

	[IapsEnum.ServerLuck4] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3722352301
		},
		Name = "Server Luck 4",
		Description = "",
		Rewards = {
			["ServerLuck"] = 4
		},
		Giftable = false,
		PaidRandom = true
	},

	[IapsEnum.ServerLuck5] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3722352419
		},
		Name = "Server Luck 5",
		Description = "",
		Rewards = {
			["ServerLuck"] = 5
		},
		Giftable = false,
		PaidRandom = true
	},

	[IapsEnum.ServerLuck6] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3722352505
		},
		Name = "Server Luck 6",
		Description = "",
		Rewards = {
			["ServerLuck"] = 6
		},
		Giftable = false,
		PaidRandom = true
	},

	[IapsEnum.ServerLuck7] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3722352604
		},
		Name = "Server Luck 7",
		Description = "",
		Rewards = {
			["ServerLuck"] = 7
		},
		Giftable = false,
		PaidRandom = true
	},

	[IapsEnum.ServerLuck8] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3722352718
		},
		Name = "Server Luck 8",
		Description = "",
		Rewards = {
			["ServerLuck"] = 8
		},
		Giftable = false,
		PaidRandom = true
	},

	[IapsEnum.ServerLuck9] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3722352823
		},
		Name = "Server Luck 9",
		Description = "",
		Rewards = {
			["ServerLuck"] = 9
		},
		Giftable = false,
		PaidRandom = true
	},

	[IapsEnum.ServerLuck10] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3722352909
		},
		Name = "Server Luck 10",
		Description = "",
		Rewards = {
			["ServerLuck"] = 10
		},
		Giftable = false,
		PaidRandom = true
	},

	[IapsEnum.ServerLuck11] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3722352979
		},
		Name = "Server Luck 11",
		Description = "",
		Rewards = {
			["ServerLuck"] = 11
		},
		Giftable = false,
		PaidRandom = true
	},

	-- GAMEPASSES
	[IapsEnum.VIP] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720140827,
		},
		Name = "VIP",
		Description = "",
		Rewards = {},
		Giftable = true,
		MaxPurchases = 1,
	},

	[IapsEnum.Cash2x] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720144049,
		},
		Name = "Cash 2x",
		Description = "",
		Rewards = {},
		Giftable = true,
		MaxPurchases = 1,
	},

	[IapsEnum.Cash4x] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720159982,
		},
		Name = "Cash 4x",
		Description = "",
		Rewards = {},
		Giftable = true,
		MaxPurchases = 1,
	},

	[IapsEnum.Cash8x] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720162746,
		},
		Name = "Cash 8x",
		Description = "",
		Rewards = {},
		Giftable = true,
		MaxPurchases = 1,
	},

	[IapsEnum.Cash16x] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720164032,
		},
		Name = "Cash 16x",
		Description = "",
		Rewards = {},
		Giftable = true,
		MaxPurchases = 1,
	},

	[IapsEnum.Cash32x] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720165543,
		},
		Name = "Cash 32x",
		Description = "",
		Rewards = {},
		Giftable = true,
		MaxPurchases = 1,
	},

	[IapsEnum.DigPower2x] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720145044,
		},
		Name = "Dig Power 2x",
		Description = "",
		Rewards = {},
		Giftable = true,
		MaxPurchases = 1,
	},

	[IapsEnum.AutoCollect] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720145646,
		},
		Name = "Auto Collect",
		Description = "",
		Rewards = {},
		Giftable = true,
		MaxPurchases = 1,
	},

	[IapsEnum.OfflineCash2x] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720156437,
		},
		Name = "Offline Cash 2x",
		Description = "",
		Rewards = {},
		Giftable = true,
		MaxPurchases = 1,
	},

	[IapsEnum.GiantBearTraps] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720167428,
		},
		Name = "Giant Bear Traps",
		Description = "",
		Rewards = {},
		Giftable = true,
		MaxPurchases = 1,
	},

	[IapsEnum.OmegaShovel] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3720823548,
		},
		Name = "Omega Shovel",
		Description = "",
		Rewards = {
			["OmegaShovel"] = 1,
		},
		Giftable = true,
		MaxPurchases = 1
	},

	[IapsEnum.StarterPack] = {
		Ids = {
			[IapTypesEnum.DevProduct] = 3722083712
		},
		Name = "Starter Pack",
		Description = "",
		Rewards = {
			[PlayerStatsEnum.Cash] = 10_000,
			[PlayerStatsEnum.DigPower] = 25_000,
			[IapsEnum.AutoCollect] = true
		},
		Giftable = true,
		MaxPurchases = 1
	}
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
	{
		IapsEnum.Cash2x,
		IapsEnum.Cash4x,
		IapsEnum.Cash8x,
		IapsEnum.Cash16x,
		IapsEnum.Cash32x,
	},
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
