local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local Knit = require(External:WaitForChild("Knit"))

local DebugService = {
	Name = "DebugService",
	Client = {},
	_DataService = nil
}

function DebugService:KnitStart()
	self._DataService = Knit.GetService("DataService")
end

function DebugService:IsDevPlace()
	local placeInfo = Constants.Places[game.PlaceId]
	if not placeInfo then
		return false
	end

	return placeInfo.IsDevPlace
end

return DebugService