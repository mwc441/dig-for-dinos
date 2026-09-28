local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Signal = require(External:WaitForChild("Signal"))
local Knit = require(External:WaitForChild("Knit"))

local TimeService = {
	Name = "TimeService",
	Client = {},
	TimeUpdatedSignal = Signal.new()
}

function TimeService:KnitInit()
	task.spawn(function()
		self:_InitializeTimer()
	end)
end

function TimeService:_InitializeTimer()
	while true do
		pcall(function()
			self.TimeUpdatedSignal:Fire(os.time())
		end)

		task.wait(1)
	end
end

function TimeService:GetTimeStringFromTime(time)
	local timeLeft = time
	local hoursLeft = math.floor(timeLeft / 60 / 60)
	timeLeft -= (hoursLeft * 60 * 60)

	local minutesLeft = math.floor(timeLeft / 60)
	timeLeft -= (minutesLeft * 60)

	local secondsLeft = timeLeft

	if hoursLeft <= 0 then
		if minutesLeft <= 0 then
			return string.format("%ds", secondsLeft)
		else
			return string.format("%dm%ds", minutesLeft, secondsLeft)
		end
	else
		return string.format("%dh%dm%ds", hoursLeft, minutesLeft, secondsLeft)
	end
end

return TimeService