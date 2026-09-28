local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Knit = require(External:WaitForChild("Knit"))
local Signal = require(External:WaitForChild("Signal"))

local DataController = {
	Name = "DataController",
	_DataService = nil,
	_Profile = nil,
	ProfileUpdatedSignal = Signal.new(),
	ProfileFinalizedSignal = Signal.new()
}

function DataController:KnitStart()
	self._DataService = Knit.GetService("DataService")
	self._DataService.ProfileUpdatedRemote:Connect(function(profileData)
		self._Profile = profileData
		self.ProfileUpdatedSignal:Fire(profileData)
		self.ProfileFinalizedSignal:Fire()
	end)

	self._DataService.ProfileKeyUpdatedRemote:Connect(function(key, value)
		if not self._Profile then
			return
		end

		self._Profile[key] = value

		self.ProfileUpdatedSignal:Fire(self._Profile)
		self.ProfileFinalizedSignal:Fire()
	end)
end

function DataController:GetProfile()
	if self._Profile == nil then
		self.ProfileUpdatedSignal:Wait()
	end

	return self._Profile
end

function DataController:GetProfileData(key)
	local profile = self:GetProfile()

	return profile[key]
end

return DataController