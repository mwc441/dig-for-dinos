local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Signal = require(External:WaitForChild("Signal"))
local TableUtils = require(External:WaitForChild("TableUtils"))
local Knit = require(External:WaitForChild("Knit"))

local PlayerStatsController = {
	Name = "PlayerStatsController",
	_DataController = nil,
	_Stats = {},
	StatsUpdatedSignal = Signal.new()
}

function PlayerStatsController:KnitStart()
	self._DataController = require(ReplicatedStorage.Controllers.Data.DataController)

	self._DataController.ProfileUpdatedSignal:Connect(function(profileData)
		debug.profilebegin("PlayerStats")
		if profileData.PlayerStats then
			self:_UpdateStats(profileData.PlayerStats)
		end
		debug.profileend()
	end)

	local playerStats = self._DataController:GetProfileData("PlayerStats")
	if playerStats then
		self:_UpdateStats(playerStats)
	end
end

function PlayerStatsController:_UpdateStats(updatedStats)
	if not TableUtils.Equals(updatedStats.Stats, self._Stats) then
		self._Stats = updatedStats.Stats

		self.StatsUpdatedSignal:Fire(self._Stats)
	end
end

function PlayerStatsController:GetStatValue(statEnum)
	return self._Stats[statEnum]
end

return PlayerStatsController