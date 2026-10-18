local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Knit = require(External:WaitForChild("Knit"))
local WeatherDef = require(ReplicatedConfigs:WaitForChild("WeatherDef"))

local WeatherService = {
	Name = "WeatherService",
	Client = {
		WeatherChanged = Knit.CreateSignal()
	},
	_ServerBoostsService = nil,
	_RewardsService = nil,
	_CurrentWeather = nil,
	_ForcedWeather = nil,
	_Revision = 0,
	_ActiveBoostIds = {}
}

function WeatherService:KnitStart()
	self._ServerBoostsService = require(ServerScriptService.Services.Boosts.ServerBoostsService)
	self._RewardsService = require(ServerScriptService.Services.Rewards.RewardsService)

	task.defer(function()
		while true do
			local now = DateTime.now().UnixTimestampMillis / 1000
			self:_UpdateWeather(math.floor(now))

			local nextTransition = WeatherDef.GetWeatherAtTime(now).EndsAt
			task.wait(math.min(nextTransition - now, 60))
		end
	end)
end

function WeatherService:GetCurrentWeather()
	local now = os.time()
	self:_UpdateWeather(now)
	return self._CurrentWeather
end

-- Server-only. Omit duration to use the normal 15-minute event length.
function WeatherService:ForceWeather(weatherId, duration)
	if not WeatherDef.GetWeatherInfo(weatherId) then
		return false
	end

	duration = duration or WeatherDef.DurationSeconds
	if type(duration) ~= "number" or duration ~= duration or duration <= 0 or duration == math.huge then
		return false
	end

	duration = math.ceil(duration)
	local now = os.time()
	local forcedWeather = {
		Id = weatherId,
		StartsAt = now,
		EndsAt = now + duration
	}

	self._ForcedWeather = forcedWeather
	self:_UpdateWeather(now, true)

	task.delay(math.max(forcedWeather.EndsAt - DateTime.now().UnixTimestampMillis / 1000, 0), function()
		if self._ForcedWeather == forcedWeather then
			self:_UpdateWeather(os.time())
		end
	end)

	return true
end

function WeatherService:_GetWeatherAtTime(now)
	local forcedWeather = self._ForcedWeather
	if forcedWeather and now < forcedWeather.EndsAt then
		return {
			Id = forcedWeather.Id,
			StartsAt = forcedWeather.StartsAt,
			EndsAt = forcedWeather.EndsAt,
			Forced = true
		}
	end

	return WeatherDef.GetWeatherAtTime(now)
end

function WeatherService:_UpdateWeather(now, forceRefresh)
	if self._ForcedWeather and now >= self._ForcedWeather.EndsAt then
		self._ForcedWeather = nil
	end

	local weather = self:_GetWeatherAtTime(now)
	local currentWeather = self._CurrentWeather

	if currentWeather and not forceRefresh
		and currentWeather.Id == weather.Id
		and currentWeather.StartsAt == weather.StartsAt
		and currentWeather.EndsAt == weather.EndsAt
		and currentWeather.Forced == weather.Forced then
		return
	end

	self._Revision += 1
	weather.Revision = self._Revision
	self._CurrentWeather = weather
	self:_ApplyBoosts(weather)
	self.Client.WeatherChanged:FireAll(weather)

	if weather.Id then
		local weatherInfo = WeatherDef.GetWeatherInfo(weather.Id)
		local announcement = weatherInfo.Announcement
		if announcement then
			self._RewardsService:MakeAnnouncement(announcement, weatherInfo.AnnouncementColor)
		end
	end
end

function WeatherService:_ApplyBoosts(weather)
	local nextBoosts = {}
	if weather.Id then
		for _, boost in ipairs(WeatherDef.GetWeatherInfo(weather.Id).Boosts) do
			if boost.Id and boost.Level then
				nextBoosts[boost.Id] = boost
			else
				warn(`Weather {weather.Id} has a boost without an Id or Level`)
			end
		end
	end

	for boostId in pairs(self._ActiveBoostIds) do
		if not nextBoosts[boostId] then
			self._ServerBoostsService:RemoveServerBoost(boostId)
		end
	end

	local activeBoostIds = {}
	for boostId, boost in pairs(nextBoosts) do
		local currentBoost = self._ServerBoostsService:GetServerBoost(boostId)
		if self._ActiveBoostIds[boostId] or not currentBoost then
			if currentBoost then
				self._ServerBoostsService:UpdateServerBoost(boostId, {
					Level = boost.Level,
					ExpiryTime = weather.EndsAt
				})
			else
				self._ServerBoostsService:CreateNewServerBoost({
					Id = boostId,
					Level = boost.Level,
					Time = weather.EndsAt - os.time()
				})
				self._ServerBoostsService:UpdateServerBoost(boostId, {
					ExpiryTime = weather.EndsAt
				})
			end
			activeBoostIds[boostId] = true
		else
			warn(`Weather boost {boostId} already exists as a server boost`)
		end
	end

	self._ActiveBoostIds = activeBoostIds
end

function WeatherService.Client:GetCurrentWeather(_player)
	return self.Server:GetCurrentWeather()
end

return WeatherService
