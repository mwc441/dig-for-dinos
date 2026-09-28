local ItemDef = {}

ItemDef.Categories = {
}

ItemDef.Table = {
	-- ["WoodenSword"] = {
	-- 	Name = "Wooden Sword",
	-- 	Icon = "rbxassetid://102841819641010",
	-- 	Category = ItemDef.Categories.Equips,
	-- 	EquipType = EquipTypesEnum.Sword,
	-- 	Damage = 10,
	-- 	Radius = 5.5,
	-- 	DisplayChance = 2 -- 1 / 2
	-- }
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