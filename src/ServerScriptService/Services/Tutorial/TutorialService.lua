local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local Knit = require(External:WaitForChild("Knit"))

local STEP_NAMES = {
	"Joined"
}
local MAX_STEP = #STEP_NAMES

local TutorialService = {
	Name = "TutorialService",
	Client = {},
	_AnalyticsService = nil,
	_LoggedStepsByPlayer = {}
}

function TutorialService:KnitStart()
	self._AnalyticsService = require(ServerScriptService.Services.Analytics.AnalyticsService)
end

function TutorialService:OnPlayerAdded(player)
	self:LogOnboardingStepForPlayer(player, 1)
end

function TutorialService:OnPlayerRemoving(player)
	self._LoggedStepsByPlayer[player] = nil
end

function TutorialService:LogOnboardingStepForPlayer(player, step)
	if step > MAX_STEP then
		return
	end

	local loggedSteps = self._LoggedStepsByPlayer[player]
	if not loggedSteps then
		loggedSteps = {}
		self._LoggedStepsByPlayer[player] = loggedSteps
	end

	if loggedSteps[step] then
		return
	end

	loggedSteps[step] = true

	self._AnalyticsService:LogOnboardingFunnelStepEvent(player, step, STEP_NAMES[step])
end

function TutorialService.Client:LogOnboardingStep(player, step)
	if type(step) ~= "number" then
		return
	end

	if step <= 0 then
		return
	end

	if math.floor(step) ~= step then
		return
	end

	self.Server:LogOnboardingStepForPlayer(player, step)
end

return TutorialService
