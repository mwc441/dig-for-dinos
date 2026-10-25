local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeatherDef = require(ReplicatedStorage:WaitForChild("ReplicatedConfigs"):WaitForChild("WeatherDef"))

local weatherIds = {}
for weatherId in pairs(WeatherDef.Table) do
	table.insert(weatherIds, weatherId)
end
table.sort(weatherIds)

return function(registry)
	registry:RegisterType("weather", registry.Cmdr.Util.MakeEnumType("Weather", weatherIds))
end
