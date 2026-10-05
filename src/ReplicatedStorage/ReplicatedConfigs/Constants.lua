local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local CostTypesEnum = require(Enums:WaitForChild("CostTypes"))
local RaritiesEnum = require(Enums:WaitForChild("Rarities"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))

return {
	Places = {
		[93414274508946] = {
			IsDevPlace = true
		}
	},

	GroupId = 10353739,
	GroupRanks = {
		[255] = {
			Rank = "Owner",
			Color = "51FF00",
			IsAdmin = true
		},

		[254] = {
			Rank = "Owner",
			Color = "51FF00",
			IsAdmin = true
		},

		[253] = {
			Rank = "Co-Owner", -- Celeste
			Color = "51FF00",
			IsAdmin = true
		},

		[250] = {
			Rank = "Developer",
			Color = "51FF00",
			IsAdmin = true
		}
	},

	MaxFriends = 5,
	CashPerFriend = 0.05,

	RarityColors = {
		[RaritiesEnum.Common] = Color3.fromRGB(190, 190, 190),
		[RaritiesEnum.Uncommon] = Color3.fromRGB(84, 255, 118),
		[RaritiesEnum.Rare] = Color3.fromRGB(67, 166, 255),
		[RaritiesEnum.Epic] = Color3.fromRGB(180, 82, 255),
		[RaritiesEnum.Legendary] = Color3.fromRGB(255, 198, 66)
	},

	RarityOrder = {
		RaritiesEnum.Common,
		RaritiesEnum.Uncommon,
		RaritiesEnum.Rare,
		RaritiesEnum.Epic,
		RaritiesEnum.Legendary
	},

	Icons = {
		[CostTypesEnum.Robux] = "rbxassetid://124188591047007",
		[PlayerStatsEnum.Cash] = "rbxassetid://107540056404677"
	},

	LogAnalyticsOutgoingEvents = true,

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
		DPadDown = "rbxassetid://91964245838690"
	}
}
