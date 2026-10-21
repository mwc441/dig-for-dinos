local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local CostTypesEnum = require(Enums:WaitForChild("CostTypes"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local IapsEnum = require(Enums:WaitForChild("Iaps"))

local ItemDef = {}

ItemDef.Categories = {
	Shovel = "Shovel"
}

ItemDef.Table = {
	["WoodenShovel"] = {
		Name = "Wooden Shovel",
		Icon = "rbxassetid://139669454865825",
		GradientColor = ColorSequence.new(Color3.fromRGB(181, 119, 71), Color3.fromRGB(97, 55, 31)),
		Category = ItemDef.Categories.Shovel,
		DigMultiplier = 10,
		Cost = 50,
		CostType = PlayerStatsEnum.Cash
	},

	["StoneShovel"] = {
		Name = "Stone Shovel",
		Icon = "rbxassetid://130674110839067",
		GradientColor = ColorSequence.new(Color3.fromRGB(190, 193, 196), Color3.fromRGB(92, 96, 101)),
		Category = ItemDef.Categories.Shovel,
		DigMultiplier = 25,
		Cost = 100,
		CostType = PlayerStatsEnum.Cash
	},

	["BronzeShovel"] = {
		Name = "Bronze Shovel",
		Icon = "rbxassetid://127746388495675",
		GradientColor = ColorSequence.new(Color3.fromRGB(219, 153, 79), Color3.fromRGB(119, 70, 35)),
		Category = ItemDef.Categories.Shovel,
		DigMultiplier = 50,
		Cost = 250,
		CostType = PlayerStatsEnum.Cash
	},

	["IronShovel"] = {
		Name = "Iron Shovel",
		Icon = "rbxassetid://88820009551526",
		GradientColor = ColorSequence.new(Color3.fromRGB(164, 174, 181), Color3.fromRGB(66, 74, 81)),
		Category = ItemDef.Categories.Shovel,
		DigMultiplier = 100,
		Cost = 500,
		CostType = PlayerStatsEnum.Cash
	},

	["SteelShovel"] = {
		Name = "Steel Shovel",
		Icon = "rbxassetid://86544352244466",
		GradientColor = ColorSequence.new(Color3.fromRGB(207, 223, 231), Color3.fromRGB(86, 108, 120)),
		Category = ItemDef.Categories.Shovel,
		DigMultiplier = 200,
		Cost = 1000,
		CostType = PlayerStatsEnum.Cash
	},

	["RubyShovel"] = {
		Name = "Ruby Shovel",
		Icon = "rbxassetid://116437875230999",
		GradientColor = ColorSequence.new(Color3.fromRGB(255, 91, 104), Color3.fromRGB(140, 21, 53)),
		Category = ItemDef.Categories.Shovel,
		DigMultiplier = 400,
		Cost = 2500,
		CostType = PlayerStatsEnum.Cash
	},

	["DiamondShovel"] = {
		Name = "Diamond Shovel",
		Icon = "rbxassetid://121695638192009",
		GradientColor = ColorSequence.new(Color3.fromRGB(135, 244, 255), Color3.fromRGB(36, 120, 178)),
		Category = ItemDef.Categories.Shovel,
		DigMultiplier = 800,
		Cost = 5000,
		CostType = PlayerStatsEnum.Cash
	},

	["ObsidianShovel"] = {
		Name = "Obsidian Shovel",
		Icon = "rbxassetid://93297360218572",
		GradientColor = ColorSequence.new(Color3.fromRGB(116, 85, 158), Color3.fromRGB(35, 27, 58)),
		Category = ItemDef.Categories.Shovel,
		DigMultiplier = 1600,
		Cost = 10000,
		CostType = PlayerStatsEnum.Cash
	},

	["InfernalShovel"] = {
		Name = "Infernal Shovel",
		Icon = "rbxassetid://123254245336737",
		GradientColor = ColorSequence.new(Color3.fromRGB(255, 147, 43), Color3.fromRGB(148, 28, 13)),
		Category = ItemDef.Categories.Shovel,
		DigMultiplier = 3200,
		Cost = 25000,
		CostType = PlayerStatsEnum.Cash
	},

	["OmegaShovel"] = {
		Name = "Omega Shovel",
		Icon = "rbxassetid://133712586068030",
		GradientColor = ColorSequence.new(Color3.fromRGB(255, 248, 184), Color3.fromRGB(222, 177, 67)),
		Category = ItemDef.Categories.Shovel,
		DigMultiplier = 6400,
		CostType = CostTypesEnum.Robux,
		IapId = IapsEnum.OmegaShovel
	}
}

function ItemDef.GetAllItems()
	return ItemDef.Table
end

function ItemDef.GetItemInfo(id)
	return ItemDef.Table[id]
end

function ItemDef.GetItemsOfCategory(category)
	local items = {}
	for itemId, info in pairs(ItemDef.Table) do
		if info.Category == category then
			items[itemId] = info
		end
	end

	return items
end

return ItemDef
