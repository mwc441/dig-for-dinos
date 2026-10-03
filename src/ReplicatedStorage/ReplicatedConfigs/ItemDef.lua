local ItemDef = {}

ItemDef.Categories = {
	Shovel = "Shovel"
}

ItemDef.Table = {
	["WoodenShovel"] = {
		Name = "Wooden Shovel",
		Icon = "",
		Category = ItemDef.Categories.Shovel,
		DigPower = 10
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
