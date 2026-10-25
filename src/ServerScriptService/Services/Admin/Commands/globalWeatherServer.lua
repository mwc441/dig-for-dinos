local ServerScriptService = game:GetService("ServerScriptService")

local WeatherService = require(ServerScriptService.Services.Weather.WeatherService)

return function(_context, weatherId, duration)
	local success, reason = WeatherService:ForceGlobalWeather(weatherId, duration)
	if not success then
		return reason
	end

	return weatherId .. " weather started in every server."
end
