local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Signal = require(External:WaitForChild("Signal"))
local TableUtils = require(External:WaitForChild("TableUtils"))
local Knit = require(External:WaitForChild("Knit"))

local InventoryController = {
	Name = "InventoryController",
	_DataController = nil,
	_Inventory = {},
	InventoryUpdatedSignal = Signal.new(),
}

function InventoryController:KnitStart()
	self._DataController = require(ReplicatedStorage.Controllers.Data.DataController)

	self._DataController.ProfileUpdatedSignal:Connect(function(profileData)
		if profileData.Inventory then
			self:_UpdateInventory(profileData.Inventory)
		end
	end)

	local inventoryData = self._DataController:GetProfileData("Inventory")
	if inventoryData then
		self:_UpdateInventory(inventoryData)
	end
end

function InventoryController:_UpdateInventory(inventoryData)
	if not TableUtils.Equals(inventoryData, self._Inventory) then
		self._Inventory = inventoryData

		self.InventoryUpdatedSignal:Fire()
	end
end

function InventoryController:GetQuantityOfItem(itemId)
	local quantity = (self._Inventory.FungibleItems or {})[itemId] or 0
	return quantity
end

function InventoryController:HasItems(itemId, quantity)
	local totalQuantity = self:GetQuantityOfItem(itemId)
	return totalQuantity >= quantity
end

function InventoryController:GetFungibleItems()
	return (self._Inventory.FungibleItems or {})
end

function InventoryController:GetNonFungibleItems()
	return (self._Inventory.NonFungibleItems or {})
end

function InventoryController:GetNonFungibleItem(guid)
	for _, nonFungibleItem in pairs(self:GetNonFungibleItems()) do
		if nonFungibleItem.Guid == guid then
			return nonFungibleItem
		end
	end
end

return InventoryController