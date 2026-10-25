local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local CostTypesEnum = require(Enums:WaitForChild("CostTypes"))
local IapsEnum = require(Enums:WaitForChild("Iaps"))
local RaritiesEnum = require(Enums:WaitForChild("Rarities"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local MutationsEnum = require(Enums:WaitForChild("Mutations"))

return {
	Places = {
		[93414274508946] = {
			IsDevPlace = true,
		},
	},

	GroupId = 10353739,
	GroupRanks = {
		[255] = {
			Rank = "Owner",
			Color = "51FF00",
			IsAdmin = true,
		},

		[254] = {
			Rank = "Owner",
			Color = "51FF00",
			IsAdmin = true,
		},

		[253] = {
			Rank = "Co-Owner", -- Celeste
			Color = "51FF00",
			IsAdmin = true,
		},

		[250] = {
			Rank = "Developer",
			Color = "51FF00",
			IsAdmin = true,
		},
	},
	GroupReward = {
		[PlayerStatsEnum.Cash] = 500,
	},

	MaxFriends = 5,
	CashPerFriend = 0.1,
	CashPacks = {
		IapsEnum.SmallCashPack,
		IapsEnum.MediumCashPack,
		IapsEnum.LargeCashPack,
		IapsEnum.GiantCashPack,
		IapsEnum.MassiveCashPack,
	},

	RarityOrder = {
		RaritiesEnum.Common,
		RaritiesEnum.Uncommon,
		RaritiesEnum.Rare,
		RaritiesEnum.Epic,
		RaritiesEnum.Legendary,
		RaritiesEnum.Mythical,
		RaritiesEnum.Secret,
	},

	Icons = {
		[CostTypesEnum.Robux] = "rbxassetid://124188591047007",
		[PlayerStatsEnum.Cash] = "rbxassetid://107540056404677",
		[PlayerStatsEnum.DigPower] = "rbxassetid://87407472042343"
	},

	LogAnalyticsOutgoingEvents = true,

	MutationGradients = {
		[MutationsEnum.Admin] = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("#000000")),
			ColorSequenceKeypoint.new(0.2, Color3.fromHex("#ffffff")),
			ColorSequenceKeypoint.new(0.28, Color3.fromHex("#000000")),
			ColorSequenceKeypoint.new(0.55, Color3.fromHex("#ffffff")),
			ColorSequenceKeypoint.new(0.62, Color3.fromHex("#000000")),
			ColorSequenceKeypoint.new(1, Color3.fromHex("#ffffff")),
		}),

		[MutationsEnum.Flame] = ColorSequence.new(Color3.fromHex("#ffb35d"), Color3.fromHex("#ff0202")),

		[MutationsEnum.Gold] = ColorSequence.new(Color3.fromHex("#fdff81"), Color3.fromHex("#ff7f0f")),

		[MutationsEnum.Void] = ColorSequence.new(Color3.fromHex("#d29eff"), Color3.fromHex("#7e15ff")),
	},

	MutationFlipbooks = {
		[MutationsEnum.Flame] = {
			Id = "rbxassetid://114558212950407",
			FPS = 15,
			Row = 4,
			Size = Vector2.new(256, 256),
			Tiles = 16,
		},

		[MutationsEnum.Gold] = {
			Id = "rbxassetid://9358765944",
			FPS = 5,
			Row = 4,
			Size = Vector2.new(1024, 1024),
			Tiles = 16,
			Color = ColorSequence.new(Color3.fromRGB(255, 186, 25)),
		},

		[MutationsEnum.Void] = {
			Id = "rbxassetid://15371082237",
			FPS = 16,
			Row = 4,
			Size = Vector2.new(512, 512),
			Tiles = 16,
			Color = ColorSequence.new(Color3.fromRGB(178, 11, 255)),
		},
	},

	ServerLuckOrder = {
		IapsEnum.ServerLuck1,
		IapsEnum.ServerLuck2,
		IapsEnum.ServerLuck3,
		IapsEnum.ServerLuck4,
		IapsEnum.ServerLuck5,
		IapsEnum.ServerLuck6,
		IapsEnum.ServerLuck7,
		IapsEnum.ServerLuck8,
		IapsEnum.ServerLuck9,
		IapsEnum.ServerLuck10,
		IapsEnum.ServerLuck11
	},

	GamepadIcons = {
		-- PS5
		ButtonCross = "rbxassetid://127060057759811",
		ButtonCircle = "rbxassetid://127946062966284",
		ButtonSquare = "rbxassetid://85614939056215",
		ButtonTriangle = "rbxassetid://115777587636524",
		ButtonL1 = "rbxassetid://117074684918612",
		ButtonL2 = "rbxassetid://84643618458743",
		ButtonL3 = "rbxassetid://77959125816639",
		ButtonR1 = "rbxassetid://110084852102460",
		ButtonR2 = "rbxassetid://123857136035099",
		ButtonR3 = "rbxassetid://74388755634452",
		ButtonOptions = "rbxassetid://109358331070525",
		ButtonShare = "rbxassetid://79576748956871",

		-- Xbox
		ButtonA = "rbxassetid://92984523016647",
		ButtonB = "rbxassetid://78331028200427",
		ButtonX = "rbxassetid://89319492272164",
		ButtonY = "rbxassetid://88080305150671",
		ButtonLB = "rbxassetid://123512001113579",
		ButtonLT = "rbxassetid://135116767912121",
		ButtonLS = "rbxassetid://139631019936248",
		ButtonRB = "rbxassetid://89724752104951",
		ButtonRT = "rbxassetid://91047979879459",
		ButtonRS = "rbxassetid://102428622838725",
		ButtonStart = "rbxassetid://102428622838725",
		ButtonSelect = "rbxassetid://82419630151188",

		-- ALL
		DPadLeft = "rbxassetid://137795295394409",
		DPadUp = "rbxassetid://137054719003268",
		DPadRight = "rbxassetid://109554125028012",
		DPadDown = "rbxassetid://91964245838690",
	},
}
