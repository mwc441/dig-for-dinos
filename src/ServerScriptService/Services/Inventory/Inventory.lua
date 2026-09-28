local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Signal = require(External:WaitForChild("Signal"))
local TableUtils = require(External:WaitForChild("TableUtils"))

local Inventory = {}
Inventory.__index = Inventory

function Inventory.new(player, inventory, nonFungibles)
	local self = {}
	setmetatable(self, Inventory)

	self._Player = player
	self._FungibleItems = TableUtils.Copy(inventory)
	self._NonFungibleItems = TableUtils.Copy(nonFungibles)
	self.Changed = Signal.new()

	return self
end

-- Non fungible items
function Inventory:GetNonFungibles()
	return TableUtils.Copy(self._NonFungibleItems)
end

function Inventory:GetNonFungibleItem(guid)
	for _, nonFungibleItem in pairs(self._NonFungibleItems) do
		if nonFungibleItem.Guid == guid then
			return TableUtils.Copy(nonFungibleItem)
		end
	end
end

function Inventory:GetNonFungibleItemsOfId(itemId)
	local items = {}
	for _, nonFungibleItem in pairs(self._NonFungibleItems) do
		if nonFungibleItem.ItemId == itemId then
			table.insert(items, TableUtils.Copy(nonFungibleItem))
		end
	end

	return items
end

function Inventory:AddNonFungibleItem(itemId, metadata)
	local guid = HttpService:GenerateGUID(false)
	table.insert(self._NonFungibleItems, {
		Guid = guid,
		ItemId = itemId,
		Metadata = metadata
	})

	self.Changed:Fire()

	return guid
end

function Inventory:AddNonFungibleItems(nonFungibleItems)
	for _, nonFungibleItem in pairs(nonFungibleItems) do
		local guid = HttpService:GenerateGUID(false)
		table.insert(self._NonFungibleItems, {
			Guid = guid,
			ItemId = nonFungibleItem.ItemId,
			Metadata = nonFungibleItem.Metadata
		})
	end

	self.Changed:Fire()
end

function Inventory:UpdateNonFungibleItem(guid, newMetadata)
	for _, nonFungibleItem in pairs(self._NonFungibleItems) do
		if nonFungibleItem.Guid == guid then
			nonFungibleItem.Metadata = TableUtils.Copy(newMetadata)

			self.Changed:Fire()

			return true
		end
	end
end

function Inventory:RemoveNonFungibleItem(guid)
	local indexToRemove
	for index, nonFungibleItem in pairs(self._NonFungibleItems) do
		if nonFungibleItem.Guid == guid then
			indexToRemove = index
			break
		end
	end

	if indexToRemove then
		table.remove(self._NonFungibleItems, indexToRemove)

		self.Changed:Fire()

		return true
	end
end

function Inventory:RemoveNonFungibleItems(guids)
	local changed = false
	for _, guid in pairs(guids) do
		for index, nonFungibleItem in pairs(self._NonFungibleItems) do
			if nonFungibleItem.Guid == guid then
				changed = true

				table.remove(self._NonFungibleItems, index)

				break
			end
		end
	end

	if changed then
		self.Changed:Fire()
	end

	return changed
end

-- Fungible Items
function Inventory:GetInventoryItems()
	return TableUtils.Copy(self._FungibleItems)
end

function Inventory:GetQuantityOfItem(itemId)
	return self._FungibleItems[itemId] or 0
end

function Inventory:AddItems(itemQuantityPairs)
	for itemId, quantity in pairs(itemQuantityPairs) do
		if quantity <= 0 then
			continue
		end

		self._FungibleItems[itemId] = (self._FungibleItems[itemId] or 0) + quantity
	end

	self.Changed:Fire()
end

function Inventory:AddItem(itemId, quantity)
	if quantity <= 0 then
		return
	end

	self._FungibleItems[itemId] = (self._FungibleItems[itemId] or 0) + quantity

	self.Changed:Fire()
end

function Inventory:RemoveItems(itemQuantityPairs)
	for itemId, quantity in pairs(itemQuantityPairs) do
		if quantity <= 0 then
			continue
		end

		local amountLeft = (self._FungibleItems[itemId] or 0) - quantity
		if amountLeft <= 0 then
			amountLeft = nil
		end

		self._FungibleItems[itemId] = amountLeft
	end

	self.Changed:Fire()
end

function Inventory:RemoveItem(itemId, quantity)
	if quantity <= 0 then
		return
	end

	local amountLeft = (self._FungibleItems[itemId] or 0) - quantity
	if amountLeft <= 0 then
		amountLeft = nil
	end

	self._FungibleItems[itemId] = amountLeft

	self.Changed:Fire()
end

function Inventory:Destroy()
	self.Changed:Destroy()
end

return Inventory