local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local Knit = require(External:WaitForChild("Knit"))

local STEP_NAMES = {
	"Joined",
	"Dig First Dirt",
	"Bring Back First Dino",
	"Place Dino On Base",
	"Collect money from dino",
	"Dig in excavation site",
	"Buy first shovel",
	"Buy first upgrade"
}
local MAX_STEP = #STEP_NAMES
local TUTORIAL_STEP_KEY = "TutorialStep"

local TutorialService = {
	Name = "TutorialService",
	Client = {},
	_AnalyticsService = nil,
	_DataService = nil,
	_LoggedStepsByPlayer = {}
}

function TutorialService:KnitStart()
	self._AnalyticsService = require(ServerScriptService.Services.Analytics.AnalyticsService)
	self._DataService = require(ServerScriptService.Services.Data.DataService)
end

function TutorialService:OnPlayerAdded(player)
	self:LogOnboardingStepForPlayer(player, 1)
end

function TutorialService:OnPlayerRemoving(player)
	self._LoggedStepsByPlayer[player] = nil
end

function TutorialService:GetNextStepForPlayer(player)
	local nextStep = self._DataService:GetPlayerData(player, TUTORIAL_STEP_KEY, 1)
	if type(nextStep) ~= "number" then
		return 1
	end

	return math.clamp(math.floor(nextStep), 1, MAX_STEP)
end

function TutorialService:LogOnboardingStepForPlayer(player, step)
	if type(step) ~= "number" or step < 1 or step > MAX_STEP or math.floor(step) ~= step then
		return false
	end

	local nextStep = self:GetNextStepForPlayer(player)
	if step == 1 then
		if nextStep ~= 1 then return false end
	elseif step == nextStep then
		return true
	elseif step == nextStep + 1 then
		self._DataService:SetPlayerData(player, TUTORIAL_STEP_KEY, step)
	else
		return false
	end

	local loggedSteps = self._LoggedStepsByPlayer[player]
	if not loggedSteps then
		loggedSteps = {}
		self._LoggedStepsByPlayer[player] = loggedSteps
	end

	if loggedSteps[step] then
		return true
	end

	loggedSteps[step] = true

	self._AnalyticsService:LogOnboardingFunnelStepEvent(player, step, STEP_NAMES[step])
	return true
end

function TutorialService.Client:GetNextStep(player)
	return self.Server:GetNextStepForPlayer(player)
end

function TutorialService.Client:LogOnboardingStep(player, step)
	return self.Server:LogOnboardingStepForPlayer(player, step)
end

return TutorialService
