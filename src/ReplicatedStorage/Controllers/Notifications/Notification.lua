local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local External = ReplicatedStorage:WaitForChild("External")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local NotificationNoise = Sounds:WaitForChild("NotificationNoise")
local ClientAssets = Assets:WaitForChild("ClientAssets")
local NotificationGui = ClientAssets:WaitForChild("Notification")
local GuiModules = ReplicatedStorage:WaitForChild("GuiModules")
local Signal = require(External:WaitForChild("Signal"))
local NotificationTypesEnum = require(Enums:WaitForChild("NotificationTypes"))
local GuiButton = require(GuiModules:WaitForChild("Button"))

local Notification = {}
Notification.__index = Notification

-- Required Args:
-- NotificationType
function Notification.new(args, zIndex)
	local self = {}
	setmetatable(self, Notification)

	self.Exited = Signal.new()
	self.Destroyed = Signal.new()

	self._Gui = nil

	self:_CreateGui(args.Message, zIndex)

	if args.NotificationType == NotificationTypesEnum.Confirmation then
		self:_SetupConfirmation(args.ConfirmText, args.DeclineText, args.ConfirmCallback, args.DeclineCallback)
	elseif args.NotificationType == NotificationTypesEnum.Okay then
		self:_SetupOkay(args.OkayText)
	elseif args.NotificationType == NotificationTypesEnum.Players then
		self:_SetupPlayers(args.Players, args.Callback)
	end

	return self
end

function Notification:_CreateGui(notificationMessage, zIndex)
	local newNotificationGui = NotificationGui:Clone()
	newNotificationGui.NotificationText.Text = notificationMessage or ""
	newNotificationGui.ZIndex = newNotificationGui.ZIndex + (zIndex or 0)
	newNotificationGui.Visible = true
	newNotificationGui.Parent = Player:WaitForChild("PlayerGui"):WaitForChild("Main")

	local exitButton = GuiButton.new(newNotificationGui.ExitButton)
	exitButton:SetCallback(function()
		self.Exited:Fire()
		self:Destroy()
	end)
	exitButton:SetBounce(false)

	NotificationNoise:Play()

	self._Gui = newNotificationGui
end

function Notification:_SetupOkay(okayText)
	local okayScreen = self._Gui.Okay

	local okayButton = okayScreen:FindFirstChild("OkayButton")
	if not okayButton then
		return
	end

	okayButton.OkayText.Text = okayText

	local button = GuiButton.new(okayButton)
	button:SetCallback(function()
		self:Destroy()
	end)
	button:SetBounce(false)

	okayScreen.Visible = true
end

function Notification:_SetupConfirmation(confirmText, declineText, confirmCallback, declineCallback)
	self._Gui.Confirmation.Visible = true

	self._Gui.Confirmation.ConfirmButton.ConfirmText.Text = confirmText
	local confirmButton = GuiButton.new(self._Gui.Confirmation.ConfirmButton)
	confirmButton:SetCallback(function()
		if type(confirmCallback) == "function" then
			confirmCallback()
		end

		self:Destroy()
	end)
	confirmButton:SetBounce(false)

	self._Gui.Confirmation.DeclineButton.DeclineText.Text = declineText
	local declineButton = GuiButton.new(self._Gui.Confirmation.DeclineButton)
	declineButton:SetCallback(function()
		if type(declineCallback) == "function" then
			declineCallback()
		end

		self:Destroy()
	end)
	declineButton:SetBounce(false)

	self.Exited:Connect(function()
		if type(declineCallback) == "function" then
			declineCallback()
		end
	end)
end

function Notification:_SetupPlayers(playerIds, callback)
	local playerScreen = self._Gui.Players
	local playerTemplate = playerScreen.Templates.PlayerTemplate
	local playersScroll = playerScreen.PlayersScroll

	if not playerIds then
		playerIds = {}
		for _, player in pairs(Players:GetPlayers()) do
			table.insert(playerIds, player.UserId)
		end
	end

	for index, playerId in pairs(playerIds) do
		if playerId == Player.UserId then
			continue
		end

		local player = Players:GetPlayerByUserId(playerId)

		local newTemplate = playerTemplate:Clone()
		newTemplate.Visible = true
		newTemplate.LayoutOrder = index
		newTemplate.Parent = playersScroll

		local button = GuiButton.new(newTemplate.Button)
		button:SetCallback(function()
			if type(callback) == "function" then
				callback(playerId)
			end

			self:Destroy()
		end)

		task.spawn(function()
			newTemplate.PlayerImage.Image = ""
			newTemplate.PlayerNameText.Text = ""

			if player then
				newTemplate.PlayerNameText.Text = player.DisplayName
			else
				pcall(function()
					newTemplate.PlayerNameText.Text = Players:GetNameFromUserIdAsync(playerId)
				end)
			end

			pcall(function()
				local playerImage = Players:GetUserThumbnailAsync(playerId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size352x352)
				newTemplate.PlayerImage.Image = playerImage
			end)
		end)
	end

	playerScreen.Visible = true
end

function Notification:Destroy()
	if self._Gui then
		self._Gui:Destroy()
	end

	self.Destroyed:Fire()
	self.Destroyed:DisconnectAll()
	self.Destroyed = nil

	self.Exited:Destroy()
	self.Exited = nil
end

return Notification