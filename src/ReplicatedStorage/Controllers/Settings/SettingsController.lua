local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local GuiButton = require(GuiModules:WaitForChild("Button"))
local Slider = require(GuiModules:WaitForChild("Slider"))
local SettingsDef = require(ReplicatedConfigs:WaitForChild("SettingsDef"))
local Signal = require(External:WaitForChild("Signal"))
local TopbarPlus = require(External:WaitForChild("TopbarPlus"))
local Knit = require(External:WaitForChild("Knit"))

local SettingsController = {
	Name = "SettingsController",
	_SettingsService = nil,
	_DataController = nil,
	_HudController = nil,
	_CurrentSettings = {},
	SettingUpdated = Signal.new()
}

function SettingsController:KnitInit()
	local mainGui = Player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local settingsFrame = mainGui:WaitForChild("SettingsFrame")

	self._Gui = {
		Frame = settingsFrame,
		SettingsList = settingsFrame:WaitForChild("SettingsList"):WaitForChild("SettingsList"),
		SettingTemplate = settingsFrame:WaitForChild("Templates"):WaitForChild("SettingTemplate"),
		ExitButton = settingsFrame:WaitForChild("ExitButton")
	}

	TopbarPlus.setDisplayOrder(0)
	local settingIcon = TopbarPlus.new()
	settingIcon:align("Right"):setLabel(""):oneClick(true):setImage("rbxassetid://99761733405261").selected:Connect(function()
		self:SetVisibility(not self._Gui.Frame.Visible, true)
	end)

	local exitButton = GuiButton.new(self._Gui.ExitButton)
	exitButton:SetCallback(function()
		self:SetVisibility(false, true)
	end)
end

function SettingsController:KnitStart()
	self._DataController = require(ReplicatedStorage.Controllers.Data.DataController)
	self._HudController = require(ReplicatedStorage.Controllers.Hud.HudController)
	self._SettingsService = Knit.GetService("SettingsService")

	local defaultSettings = {}
	for settingId, info in pairs(SettingsDef.GetAllSettings()) do
		defaultSettings[settingId] = info.Default
	end

	local settingsData = self._DataController:GetProfileData("Settings")
	if settingsData then
		-- If the server doesn't have a value for a setting
		-- then set it to the default setting
		for settingId, defaultValue in pairs(defaultSettings) do
			local value = settingsData.Settings[settingId]

			if value == nil then
				settingsData.Settings[settingId] = defaultValue
			end
		end

		self:_ConfigureSettings(settingsData.Settings)
	else
		self:_ConfigureSettings(defaultSettings)
	end

	self._SettingsLoaded = true
end

function SettingsController:_ConfigureSettings(settingsTable)
	for settingId, value in pairs(settingsTable) do
		if self._CurrentSettings[settingId] ~= value then
			self:ConfigureSetting(settingId, value)
		end
	end
end

function SettingsController:ConfigureSetting(settingId, value)
	self._CurrentSettings[settingId] = value

	self.SettingUpdated:Fire(settingId, value)

	self:_UpdateUi()

	return self._SettingsService:UpdateSetting(settingId, value)
end

function SettingsController:ConfigureSettingClientOnly(settingId, value)
	self._CurrentSettings[settingId] = value

	self.SettingUpdated:Fire(settingId, value)

	self:_UpdateUi()
end

function SettingsController:GetSetting(settingId)
	local setting = self._CurrentSettings[settingId]
	if setting == nil then
		local settingInfo = SettingsDef.GetSettingsInfo(settingId)
		if not settingInfo then
			return
		end

		setting = settingInfo.Default
	end

	return setting
end

function SettingsController:WaitForSettings()
	while not self._SettingsLoaded do
		task.wait()
	end
end

-- GUI STUFF
function SettingsController:SetVisibility(visible, toTween)
	local hideTrack = require(self._Gui.Frame.Animator).Hide
	local openTrack = require(self._Gui.Frame.Animator).Open

	if visible then
		self._Gui.Frame.Visible = visible
		self:_SetupUi()
		self._HudController:SetCurrentlyActiveFrame(self)
		hideTrack:Stop()
		self._Hiding = false
		openTrack:Play()
	else
		local function clear()
			self._Gui.Frame.Visible = visible
			self:_ClearUi()
			self._HudController:ClearCurrentlyActiveFrame(self)
		end

		if toTween then
			if self._Hiding then return end

			self._Hiding = true
			hideTrack:Play()
			hideTrack.Completed:Once(function()
				self._Hiding = false
				clear()
			end)
		else
			clear()
		end
	end
end

function SettingsController:_SetupUi()
	for settingId, settingInfo in pairs(SettingsDef.GetAllSettings()) do
		local showInUi = settingInfo.ShowInUi
		if showInUi == nil then
			showInUi = true
		end

		if not showInUi then
			continue
		end

		local newSettingTemplate = self._Gui.SettingTemplate:Clone()

		newSettingTemplate.NameText.Text = settingInfo.Name or ""
		newSettingTemplate.DarkNameText.Text = settingInfo.Name or ""

		newSettingTemplate.LayoutOrder = settingInfo.Order or 1000
		newSettingTemplate.Name = settingId
		newSettingTemplate.Visible = true
		newSettingTemplate.Parent = self._Gui.SettingsList

		if settingInfo.Type == "number" and settingInfo.SetType == "Slider" then
			local progressBar = newSettingTemplate.ProgressBar
			progressBar.Visible = true

			local slider = Slider.new(progressBar)
			slider:SetPercentage(self:GetSetting(settingId) or settingInfo.Default)

			slider.SliderMoved:Connect(function()
				self:ConfigureSettingClientOnly(settingId, slider:GetPercentage())
			end)

			slider.SliderFinishedMoving:Connect(function()
				self:ConfigureSetting(settingId, slider:GetPercentage())
			end)
		end

		if settingInfo.Type == "number" and settingInfo.SetType == "InputBox" then
			local inputBox = newSettingTemplate.InputBox :: TextBox
			inputBox.Text = tostring(self:GetSetting(settingId) or settingInfo.Default)
			inputBox.Visible = true

			inputBox:GetPropertyChangedSignal("Text"):Connect(function()
				local text = inputBox.Text
				local number = tonumber(text)
				if not number then
					inputBox.Text = tostring(settingInfo.Default)
					return
				end

				inputBox.Text = tostring(number)
				self:ConfigureSetting(settingId, number)
			end)
		end

		if settingInfo.Type == "boolean" then
			local toggleButton = newSettingTemplate.ToggleButton
			toggleButton.Visible = true

			local button = GuiButton.new(toggleButton)
			button:SetCallback(function()
				self:ConfigureSetting(settingId, not self:GetSetting(settingId))
			end)
		end
	end

	self:_UpdateUi()
end

function SettingsController:_UpdateUi()
	if not self._Gui.Frame.Visible then
		return
	end

	for _, template in pairs(self._Gui.SettingsList:GetChildren()) do
		if not template:IsA(self._Gui.SettingTemplate.ClassName) then
			continue
		end

		local settingId = template.Name
		local settingInfo = SettingsDef.GetSettingsInfo(settingId)
		if not settingInfo then
			continue
		end

		if settingInfo.Type == "boolean" then
			local toggleButton = template.ToggleButton
			toggleButton.OnText.Text = self:GetSetting(settingId) and "ON" or "OFF"
		end
	end
end

function SettingsController:_ClearUi()
	for _, template in pairs(self._Gui.SettingsList:GetChildren()) do
		if template:IsA(self._Gui.SettingTemplate.ClassName) then
			template:Destroy()
		end
	end
end

return SettingsController