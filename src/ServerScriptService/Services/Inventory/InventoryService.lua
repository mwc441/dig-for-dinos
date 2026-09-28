local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local DataKeys = require(ServerScriptService:WaitForChild("ServerConfigs"):WaitForChild("DataKeys"))
local Knit = require(External:WaitForChild("Knit"))
local Signal = require(External:WaitForChild("Signal"))
local Inventory = require(script.Parent:WaitForChild("Inventory"))

local INVENTORY_KEY = DataKeys.Inventory
local INVENTORY_DEFAULT_DATA = {
	Version = 1,
	FungibleItems = {},
	NonFungibleItems = {}
}

local InventoryService = {
	Name = "InventoryService",
	Client = {},
	_DataService = nil,
	_Inventories = {},
	PlayerInventoryUpdated = Signal.new()
}

function InventoryService:KnitStart()
	self._DataService = require(ServerScriptService.Services.Data.DataService)
end

function InventoryService:OnPlayerAdded(player)
	self:_CreateInventoryForPlayer(player)
end

function InventoryService:OnPlayerRemoving(player)
	self:_DestroyInventoryForPlayer(player)
end

function InventoryService:_GetInventoryForPlayer(player)
	return self._Inventories[player]
end

function InventoryService:_CreateInventoryForPlayer(player)
	local playerInventoryData = self._DataService:GetPlayerData(player, INVENTORY_KEY, INVENTORY_DEFAULT_DATA)
	local newInventory = Inventory.new(player, playerInventoryData.FungibleItems, playerInventoryData.NonFungibleItems)

	self._Inventories[player] = newInventory

	newInventory.Changed:Connect(function()
		self:_SerializeInventory(player)

		self.PlayerInventoryUpdated:Fire(player)
	end)
end

function InventoryService:_DestroyInventoryForPlayer(player)
	local inventory = self._Inventories[player]
	if inventory then
		inventory:Destroy()
	end
	self._Inventories[player] = nil
end

function InventoryService:_SerializeInventory(player)
	local inventory = self:_GetInventoryForPlayer(player)
	if not inventory then
		return
	end

	local inventoryData = self._DataService:GetPlayerData(player, INVENTORY_KEY, INVENTORY_DEFAULT_DATA)

	inventoryData.FungibleItems = inventory:GetInventoryItems()
	inventoryData.NonFungibleItems = inventory:GetNonFungibles()

	self._DataService:SetPlayerData(player, INVENTORY_KEY, inventoryData) -- To trigger auto-replication to client
end

-- Non-fungibles
function InventoryService:GetNonFungiblesForPlayer(player)
	local inventory = self:_GetInventoryForPlayer(player)
	if not inventory then
		return
	end

	return inventory:GetNonFungibles()
end

function InventoryService:GetNonFungibleItemForPlayer(player, guid)
	local inventory = self:_GetInventoryForPlayer(player)
	if not inventory then
		return
	end

	return inventory:GetNonFungibleItem(guid)
end

function InventoryService:GetNonFungibleItemsOfIdForPlayer(player, itemId)
	local inventory = self:_GetInventoryForPlayer(player)
	if not inventory then
		return
	end

	return inventory:GetNonFungibleItemsOfId(itemId)
end

function InventoryService:AddNonFungibleItemForPlayer(player, itemId, metadata)
	local inventory = self:_GetInventoryForPlayer(player)
	if not inventory then
		return
	end

	return inventory:AddNonFungibleItem(itemId, metadata)
end

function InventoryService:AddNonFungibleItemsForPlayer(player, nonFungibleItems)
	local inventory = self:_GetInventoryForPlayer(player)
	if not inventory then
		return
	end

	return inventory:AddNonFungibleItems(nonFungibleItems)
end

function InventoryService:UpdateNonFungibleItemForPlayer(player, guid, newMetadata)
	local inventory = self:_GetInventoryForPlayer(player)
	if not inventory then
		return
	end

	return inventory:UpdateNonFungibleItem(guid, newMetadata)
end

function InventoryService:RemoveNonFungibleItemForPlayer(player, guid)
	local inventory = self:_GetInventoryForPlayer(player)
	if not inventory then
		return
	end

	return inventory:RemoveNonFungibleItem(guid)
end

function InventoryService:RemoveNonFungibleItemsForPlayer(player, guids)
	local inventory = self:_GetInventoryForPlayer(player)
	if not inventory then
		return
	end

	return inventory:RemoveNonFungibleItems(guids)
end

-- Fungible items
function InventoryService:AddItemsToPlayersInventory(player, itemQuantityPairs)
	local inventory = self:_GetInventoryForPlayer(player)
	if not inventory then
		return
	end

	inventory:AddItems(itemQuantityPairs)
end

function InventoryService:RemoveItemsFromPlayersInventory(player, itemQuantityPairs)
	local inventory = self:_GetInventoryForPlayer(player)
	if not inventory then
		return
	end

	inventory:RemoveItems(itemQuantityPairs)
end

function InventoryService:GetQuantityOfItemForPlayer(player, itemId)
	local inventory = self:_GetInventoryForPlayer(player)
	if not inventory then
		return 0
	end

	return inventory:GetQuantityOfItem(itemId)
end

function InventoryService:GetInventoryItemsForPlayer(player)
	local inventory = self:_GetInventoryForPlayer(player)
	if not inventory then
		return
	end

	return inventory:GetInventoryItems()
end

function InventoryService:CheckPlayerInventoryForItems(player, itemId, quantity)
	if type(quantity) ~= "number" or type(itemId) ~= "string" then
		return false
	end

	if quantity < 0 then
		return false
	end

	local inventory = self:_GetInventoryForPlayer(player)
	if not inventory then
		return false
	end

	if inventory:GetQuantityOfItem(itemId) >= quantity then
		return true
	end
end

return InventoryService