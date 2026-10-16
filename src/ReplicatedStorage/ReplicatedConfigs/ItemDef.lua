local ItemDef = {}

ItemDef.Categories = {
	Shovel = "Shovel"
}

ItemDef.Table = {
	["WoodenShovel"] = {
		Name = "Wooden Shovel",
		Icon = "rbxassetid://105832751310248",
		GradientColor = ColorSequence.new(Color3.fromRGB(181, 119, 71), Color3.fromRGB(97, 55, 31)),
		Category = ItemDef.Categories.Shovel,
		DigMultiplier = 10,
		Cost = 50
	},

	["StoneShovel"] = {
		Name = "Stone Shovel",
		Icon = "rbxassetid://98327615004173",
		GradientColor = ColorSequence.new(Color3.fromRGB(190, 193, 196), Color3.fromRGB(92, 96, 101)),
		Category = ItemDef.Categories.Shovel,
		DigMultiplier = 25,
		Cost = 100
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
