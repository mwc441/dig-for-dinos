local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local TableUtils = require(External:WaitForChild("TableUtils"))
local Knit = require(External:WaitForChild("Knit"))
local Signal = require(External:WaitForChild("Signal"))

local UpgradeController = {
	Name = "UpgradeController",
	_DataController = nil,
	_Upgrades = {},
	UpgradesUpdated = Signal.new()
}

function UpgradeController:KnitStart()
	self._DataController = require(ReplicatedStorage.Controllers.Data.DataController)

	local upgradeData = self._DataController:GetProfileData("Upgrades")
	if upgradeData then
		self:_UpdateUpgrades(upgradeData.Upgrades)
	end

	self._DataController.ProfileUpdatedSignal:Connect(function(profileData)
		if profileData.Upgrades then
			self:_UpdateUpgrades(profileData.Upgrades.Upgrades)
		end
	end)
end

function UpgradeController:_UpdateUpgrades(upgrades)
	if not TableUtils.Equals(upgrades, self._Upgrades) then
		self._Upgrades = upgrades
		self.UpgradesUpdated:Fire()
	end
end

function UpgradeController:GetUpgradeLevel(upgradeId)
	return self._Upgrades[upgradeId] or 0
end

return UpgradeController