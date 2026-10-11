local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Knit = require(External:WaitForChild("Knit"))
local TableUtils = require(External:WaitForChild("TableUtils"))
local Signal = require(External:WaitForChild("Signal"))

local IndexController = {
	Name = "IndexController",
	_DataController = nil,
	_Index = {},
	IndexUpdated = Signal.new()
}

function IndexController:KnitStart()
	self._DataController = require(ReplicatedStorage.Controllers.Data.DataController)

	local indexData = self._DataController:GetProfileData("Index")
	if indexData then
		self:_UpdateIndex(indexData)
	end

	self._DataController.ProfileUpdatedSignal:Connect(function(profileData)
		if profileData.Index then
			self:_UpdateIndex(profileData.Index)
		end
	end)
end

function IndexController:_UpdateIndex(indexData)
	if not TableUtils.Equals(self._Index, indexData) then
		self._Index = indexData
		self.IndexUpdated:Fire()
	end
end

function IndexController:IsUnlocked(category, itemId)
	local unlocked = self._Index.Unlocked or {}

	local itemsUnlocked = unlocked[category] or {}

	return table.find(itemsUnlocked, itemId) ~= nil
end

function IndexController:GetLevelClaimed(category)
	local claimed = self._Index.Claimed or {}

	return claimed[category] or 0
end

function IndexController:GetUnlocked(category)
	local unlocked = self._Index.Unlocked or {}

	return unlocked[category] or {}
end

return IndexController