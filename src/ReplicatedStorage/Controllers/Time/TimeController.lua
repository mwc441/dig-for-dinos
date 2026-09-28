local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local UtilFunctions = require(Utils:WaitForChild("UtilFunctions"))
local Signal = require(External:WaitForChild("Signal"))
local Knit = require(External:WaitForChild("Knit"))

local TimeController = {
	Name = "TimeController",
	TimeUpdatedSignal = Signal.new()
}

function TimeController:KnitStart()
	task.spawn(function()
		self:_InitializeTimer()
	end)
end

function TimeController:_InitializeTimer()
	while true do
		self.TimeUpdatedSignal:Fire(os.time())

		task.wait(1)
	end
end

function TimeController:GetTimeStringFromTime(time)
	return UtilFunctions.GetTimeStringFromTime(time)
end

return TimeController