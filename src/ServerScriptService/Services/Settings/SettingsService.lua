local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local ServerConfigs = ServerScriptService:WaitForChild("ServerConfigs")
local SettingsDef = require(ReplicatedConfigs:WaitForChild("SettingsDef"))
local DataKeys = require(ServerConfigs:WaitForChild("DataKeys"))
local Signal = require(External:WaitForChild("Signal"))
local Knit = require(External:WaitForChild("Knit"))

local SETTINGS_KEY = DataKeys.Settings
local SETTINGS_DEFAULT_DATA = {
	Version = 1,
	Settings = {}
}

local SettingsService = {
	Name = "SettingsService",
	Client = {},
	_DataService = nil,
	PlayerSettingUpdated = Signal.new()
}

function SettingsService:KnitStart()
	self._DataService = require(ServerScriptService.Services.Data.DataService)
end

function SettingsService:GetSettingForPlayer(player, settingId)
	local playerSettingsData = self._DataService:GetPlayerData(player, SETTINGS_KEY, SETTINGS_DEFAULT_DATA)

	local setting = playerSettingsData.Settings[settingId]
	if setting == nil then
		local settingInfo = SettingsDef.GetSettingsInfo(settingId)
		if not settingInfo then
			return
		end

		setting = settingInfo.Default
	end

	return setting
end

function SettingsService:_UpdateSettingForPlayer(player, settingId, value)
	local settingsInfo = SettingsDef.GetSettingsInfo(settingId)
	if not settingsInfo then
		return
	end

	local settingType = settingsInfo.Type
	if type(value) ~= settingType then
		return
	end

	if value ~= value then -- nan check
		return
	end

	local playerSettingsData = self._DataService:GetPlayerData(player, SETTINGS_KEY, SETTINGS_DEFAULT_DATA)

	playerSettingsData.Settings[settingId] = value

	self._DataService:SetPlayerData(player, SETTINGS_KEY, playerSettingsData)

	self.PlayerSettingUpdated:Fire(player, settingId, value)
end

function SettingsService.Client:UpdateSetting(player, settingId, value)
	if (type(settingId) ~= "string") then
		return
	end

	self.Server:_UpdateSettingForPlayer(player, settingId, value)
end

return SettingsService