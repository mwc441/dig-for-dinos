local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Signal = require(External:WaitForChild("Signal"))
local TableUtils = require(External:WaitForChild("TableUtils"))
local Knit = require(External:WaitForChild("Knit"))

local TimerController = {
	Name = "TimerController",
	_DataController = nil,
	_Timers = {},
	TimersUpdatedSignal = Signal.new()
}

function TimerController:KnitStart()
	self._DataController = require(ReplicatedStorage.Controllers.Data.DataController)

	local timersData = self._DataController:GetProfileData("Timers")
	if timersData then
		self:_UpdateTimers(timersData)
	end

	self._DataController.ProfileUpdatedSignal:Connect(function(profileData)
		if profileData.Timers then
			self:_UpdateTimers(profileData.Timers)
		end
	end)
end

function TimerController:_UpdateTimers(timersData)
	if not TableUtils.Equals(timersData.Timers, self._Timers) then
		self._Timers = timersData.Timers

		self.TimersUpdatedSignal:Fire()
	end
end

function TimerController:GetTimeForTimer(timerId)
	return self._Timers[timerId]
end

return TimerController
