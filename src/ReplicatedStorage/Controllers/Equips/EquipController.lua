local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Signal = require(External:WaitForChild("Signal"))
local TableUtils = require(External:WaitForChild("TableUtils"))

local EquipController = {
	Name = "EquipController",
	_DataController = nil,
	_Equips = {},
	EquipsUpdatedSignal = Signal.new()
}

function EquipController:KnitStart()
	self._DataController = require(ReplicatedStorage.Controllers.Data.DataController)

	self._DataController.ProfileUpdatedSignal:Connect(function(profileData)
		if profileData.Equips then
			self:_UpdateEquips(profileData.Equips)
		end
	end)

	local equipData = self._DataController:GetProfileData("Equips")
	if equipData then
		self:_UpdateEquips(equipData)
	end
end

function EquipController:_UpdateEquips(equipData)
	local equips = equipData.Equips or {}
	if not TableUtils.Equals(equips, self._Equips) then
		self._Equips = equips
		self.EquipsUpdatedSignal:Fire()
	end
end

function EquipController:GetEquips()
	return self._Equips
end

function EquipController:GetEquippedItem(slotId)
	return self._Equips[slotId]
end

function EquipController:IsItemEquipped(itemId)
	for _, equippedItemId in pairs(self._Equips) do
		if equippedItemId == itemId then
			return true
		end
	end

	return false
end

return EquipController
