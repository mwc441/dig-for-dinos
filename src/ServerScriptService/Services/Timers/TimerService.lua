local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local ServerConfigs = ServerScriptService:WaitForChild("ServerConfigs")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local TimersEnum = require(Enums:WaitForChild("Timers"))
local PlayerStatsEnum = require(Enums:WaitForChild("PlayerStats"))
local DataKeys = require(ServerConfigs:WaitForChild("DataKeys"))
local Knit = require(External:WaitForChild("Knit"))
local Signal = require(External:WaitForChild("Signal"))

local TIMERS_KEY = DataKeys.Timers
local TIMERS_DEFAULT_DATA = {
	Version = 1,
	Timers = {}
}

local TimerService = {
	Name = "TimerService",
	Client = {},
	_DataService = nil,
	_TimeService = nil,
	_LifecycleService = nil,
	_PlayerStatsService = nil,
	PlayerLoggedBackIn = Signal.new()
}

function TimerService:KnitStart()
	self._DataService = require(ServerScriptService.Services.Data.DataService)
	self._TimeService = require(ServerScriptService.Services.Time.TimeService)
	self._LifecycleService = require(ServerScriptService.Services.LifeCycle.LifecycleService)
	self._PlayerStatsService = require(ServerScriptService.Services.PlayerStats.PlayerStatsService)

	self._TimeService.TimeUpdatedSignal:Connect(function()
		for _, player in pairs(self._LifecycleService:GetInitializedPlayers()) do
			self._PlayerStatsService:AddToStatForPlayer(player, PlayerStatsEnum.TimePlayed, 1)
		end
	end)
end

function TimerService:OnPlayerAdded(player)
	local firstLogin = self:GetTimerForPlayer(player, TimersEnum.FirstLogin)
	if not firstLogin then
		self:SetTimerForPlayer(player, TimersEnum.FirstLogin, os.time())
	end

	local lastLogout = self:GetTimerForPlayer(player, TimersEnum.LastLogout)
	if lastLogout then
		local totalTime = os.time() - lastLogout
		if totalTime > 0 then
			self.PlayerLoggedBackIn:Fire(player, totalTime)
		end
	end
end

function TimerService:OnPlayerRemoving(player)
	self:SetTimerForPlayer(player, TimersEnum.LastLogout, os.time())
end

function TimerService:GetTimerForPlayer(player, timerId)
	local playerTimerData = self._DataService:GetPlayerData(player, TIMERS_KEY, TIMERS_DEFAULT_DATA)

	return playerTimerData.Timers[timerId]
end

function TimerService:SetTimerForPlayer(player, timerId, timeValue)
	local playerTimerData = self._DataService:GetPlayerData(player, TIMERS_KEY, TIMERS_DEFAULT_DATA)

	playerTimerData.Timers[timerId] = timeValue

	self._DataService:SetPlayerData(player, TIMERS_KEY, playerTimerData, true)

	return true
end

function TimerService:SetTimersForPlayer(player, timerPairs)
	local playerTimerData = self._DataService:GetPlayerData(player, TIMERS_KEY, TIMERS_DEFAULT_DATA)

	for timerId, timeValue in pairs(timerPairs) do
		playerTimerData.Timers[timerId] = timeValue
	end

	self._DataService:SetPlayerData(player, TIMERS_KEY, playerTimerData, true)
end

return TimerService
