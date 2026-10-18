local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local BoostsDef = require(ReplicatedConfigs:WaitForChild("BoostsDef"))
local WeatherDef = require(ReplicatedConfigs:WaitForChild("WeatherDef"))
local Knit = require(External:WaitForChild("Knit"))
local Signal = require(External:WaitForChild("Signal"))
local Weather = require(script.Parent:WaitForChild("Weather"))

local WeatherController = {
	Name = "WeatherController",
	_WeatherService = nil,
	_EventBoardController = nil,
	_TimeController = nil,
	_CurrentWeather = nil,
	_Weather = nil,
	_ScheduledWeatherIds = {},
	_BoardWindowStart = nil,
	WeatherChangedSignal = Signal.new()
}

function WeatherController:KnitStart()
	self._WeatherService = Knit.GetService("WeatherService")
	self._EventBoardController = require(ReplicatedStorage.Controllers.EventBoard.EventBoardController)
	self._TimeController = require(ReplicatedStorage.Controllers.Time.TimeController)
	self._BoardWindowStart = self._EventBoardController:GetWindowBounds(math.floor(Workspace:GetServerTimeNow()))

	self._WeatherService.WeatherChanged:Connect(function(weather)
		self:_SetWeather(weather)
		self:_RefreshUpcomingWeather()
	end)

	self._WeatherService:GetCurrentWeather():andThen(function(weather)
		self:_SetWeather(weather)
		self:_RefreshUpcomingWeather()
	end)

	self._TimeController.TimeUpdatedSignal:Connect(function()
		local windowStart = self._EventBoardController:GetWindowBounds(math.floor(Workspace:GetServerTimeNow()))
		if windowStart ~= self._BoardWindowStart then
			self._BoardWindowStart = windowStart
			self:_RefreshUpcomingWeather()
		end
	end)

	self:_RefreshUpcomingWeather()
end

function WeatherController:_RefreshUpcomingWeather()
	local now = math.floor(Workspace:GetServerTimeNow())
	local windowStart, windowEnd = self._EventBoardController:GetWindowBounds(now)
	local forcedWeather = self._CurrentWeather
	if not forcedWeather or not forcedWeather.Forced or forcedWeather.EndsAt <= now then
		forcedWeather = nil
	end

	local nextEvents = {}
	local function addWeatherEvent(weatherId, startsAt, endsAt, forced)
		local eventId = string.format("Weather:%s:%d:%d:%s", weatherId, startsAt, endsAt,
			forced and "Forced" or "Scheduled")
		local weatherInfo = WeatherDef.GetWeatherInfo(weatherId)
		local firstBoost = weatherInfo.Boosts[1]
		local boostInfo = firstBoost and BoostsDef.GetBoostInfo(firstBoost.Id)
		nextEvents[eventId] = {
			StartsAt = startsAt,
			EndsAt = endsAt,
			Text = weatherId .. " Weather",
			Color = weatherInfo.AnnouncementColor,
			Icon = boostInfo and boostInfo.Icon
		}
	end

	local cursor = windowStart
	while cursor < windowEnd do
		local weatherEvent = WeatherDef.GetWeatherAtTime(cursor)
		if weatherEvent.Id then
			local startsAt = weatherEvent.StartsAt
			local endsAt = weatherEvent.EndsAt
			if forcedWeather and startsAt < forcedWeather.EndsAt and endsAt > forcedWeather.StartsAt then
				startsAt = math.max(startsAt, forcedWeather.EndsAt)
			end

			if endsAt > now and startsAt < endsAt and startsAt < windowEnd then
				addWeatherEvent(weatherEvent.Id, startsAt, endsAt, false)
			end
		end
		cursor = weatherEvent.EndsAt
	end

	if forcedWeather and forcedWeather.StartsAt < windowEnd then
		addWeatherEvent(forcedWeather.Id, forcedWeather.StartsAt, forcedWeather.EndsAt, true)
	end

	for eventId in pairs(self._ScheduledWeatherIds) do
		if not nextEvents[eventId] then
			self._EventBoardController:RemoveEvent(eventId)
		end
	end

	for eventId, eventInfo in pairs(nextEvents) do
		if not self._ScheduledWeatherIds[eventId] then
			self._EventBoardController:ScheduleEvent(eventId, eventInfo)
		end
	end

	local scheduledIds = {}
	for eventId in pairs(nextEvents) do
		scheduledIds[eventId] = true
	end
	self._ScheduledWeatherIds = scheduledIds
end

function WeatherController:_SetWeather(weather)
	if self._CurrentWeather and weather.Revision <= self._CurrentWeather.Revision then
		return
	end

	if self._Weather then
		self._Weather:Destroy()
	end

	self._CurrentWeather = weather
	self._Weather = nil
	if weather.Id then
		self._Weather = Weather.new(weather.Id)
	end
	self.WeatherChangedSignal:Fire(weather)
end

function WeatherController:GetCurrentWeather()
	return self._CurrentWeather
end

return WeatherController
