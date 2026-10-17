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
	},

	[SettingsEnum.ShowOtherPlayerDinosaurs] = {
		Order = 3,
		Name = "Show Other's Dinos",
		Default = true,
		Type = "boolean"
	},

	[SettingsEnum.ShowOwnDinosaurs] = {
		Order = 4,
		Name = "Show Your Dinos",
		Default = true,
		Type = "boolean"
	},

	[SettingsEnum.SpeedOn] = {
		ShowInUi = false,
		Name = "Speed On",
		Default = true,
		Type = "boolean"
	}
}

function SettingsDef.GetAllSettings()
	return SettingsDef.Table
end

function SettingsDef.GetSettingsInfo(id)
	return SettingsDef.Table[id]
end

return SettingsDef
