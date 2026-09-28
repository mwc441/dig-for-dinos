local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = ReplicatedStorage:WaitForChild("Enums")
local SettingsEnum = require(Enums:WaitForChild("Settings"))

local SettingsDef = {}

SettingsDef.Table = {
	[SettingsEnum.MusicVolume] = {
		Order = 1,
		Name = "Music Volume",
		Default = 1,
		Type = "number",
		SetType = "Slider"
	},

	[SettingsEnum.SoundEffectVolume] = {
		Order = 2,
		Name = "Sound Effect Volume",
		Default = 1,
		Type = "number",
		SetType = "Slider"
	}
}

function SettingsDef.GetAllSettings()
	return SettingsDef.Table
end

function SettingsDef.GetSettingsInfo(id)
	return SettingsDef.Table[id]
end

return SettingsDef
