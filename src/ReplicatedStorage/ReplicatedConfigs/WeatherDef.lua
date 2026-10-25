local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoostsEnum = require(ReplicatedStorage:WaitForChild("Enums"):WaitForChild("Boosts"))

local WeatherDef = {}

WeatherDef.IntervalSeconds = 60 * 60
WeatherDef.DurationSeconds = 10 * 60
WeatherDef.OffsetSeconds = 15 * 60 -- 00:15 UTC, then every 45 minutes

-- Boosts entries use { Id = "WeatherBoostId", Level = 1 }.
-- Give weather boosts their own IDs in BoostsDef so they do not replace other server boosts.
WeatherDef.Table = {
	["Admin"] = {
		ManualOnly = true,
		Announcement = "[//] ADMIN WEATHER ACTIVE [//]",
		AnnouncementColor = "Zebra",
		Boosts = { { Id = BoostsEnum.AdminWeatherBoost, Level = 1 } },
	},

	["Gold"] = {
		Announcement = "✨ Gold weather has begun! ✨",
		AnnouncementColor = Color3.fromRGB(255, 205, 52),
		Boosts = { { Id = BoostsEnum.GoldWeatherBoost, Level = 1 } },
	},

	["Void"] = {
		Announcement = "🌀 Void weather has begun! 🌀",
		AnnouncementColor = Color3.fromRGB(151, 88, 255),
		Boosts = { { Id = BoostsEnum.VoidWeatherBoost, Level = 1 } },
	},

	["Flame"] = {
		Announcement = "🔥 Flame weather has begun! 🔥",
		AnnouncementColor = Color3.fromRGB(255, 102, 51),
		Boosts = { { Id = BoostsEnum.FlameWeatherBoost, Level = 1 } },
	},

	["Cash"] = {
		Announcement = "💰 Cash weather has begun! 💰",
		AnnouncementColor = Color3.fromRGB(76, 232, 104),
		Boosts = { { Id = BoostsEnum.CashWeatherBoost, Level = 1 } },
	},

	["Radioactive"] = {
		Announcement = "☢️ Radioactive weather has begun! ☢️",
		AnnouncementColor = Color3.fromRGB(176, 255, 64),
		Boosts = { { Id = BoostsEnum.RadioactiveWeatherBoost, Level = 1 } },
	},
}

local weatherIds = {}
for weatherId, info in pairs(WeatherDef.Table) do
	if not info.ManualOnly then
		table.insert(weatherIds, weatherId)
	end
end
table.sort(weatherIds)
assert(#weatherIds > 0, "WeatherDef must contain at least one weather")

-- Returns the scheduled weather or the gap at a Unix timestamp.
function WeatherDef.GetWeatherAtTime(unixTime)
	local slot = math.floor((unixTime - WeatherDef.OffsetSeconds) / WeatherDef.IntervalSeconds)
	local startsAt = slot * WeatherDef.IntervalSeconds + WeatherDef.OffsetSeconds
	local endsAt = startsAt + WeatherDef.DurationSeconds

	if unixTime >= endsAt then
		return {
			StartsAt = endsAt,
			EndsAt = startsAt + WeatherDef.IntervalSeconds,
		}
	end

	local weatherIndex = Random.new(slot):NextInteger(1, #weatherIds)
	return {
		Id = weatherIds[weatherIndex],
		StartsAt = startsAt,
		EndsAt = endsAt,
	}
end

function WeatherDef.GetWeatherInfo(id)
	return WeatherDef.Table[id]
end

return WeatherDef
