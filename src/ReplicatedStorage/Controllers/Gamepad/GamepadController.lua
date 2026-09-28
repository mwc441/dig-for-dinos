local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GamepadService = game:GetService("GamepadService")

local External = ReplicatedStorage:WaitForChild("External")
local ReplicatedConfigs = ReplicatedStorage:WaitForChild("ReplicatedConfigs")
local Constants = require(ReplicatedConfigs:WaitForChild("Constants"))
local Trove = require(External:WaitForChild("Trove"))
local Device = require(External:WaitForChild("Device"))
local Knit = require(External:WaitForChild("Knit"))

local GamepadController = {
	Name = "GamepadController"
}

function GamepadController:KnitInit()
	CollectionService:GetInstanceAddedSignal("GamepadIcon"):Connect(function(gamepadIcon)
		self:_SetupGamepadIcon(gamepadIcon)
	end)

	for _, gamepadIcon in pairs(CollectionService:GetTagged("GamepadIcon")) do
		self:_SetupGamepadIcon(gamepadIcon)
	end

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode ~= Enum.KeyCode.ButtonSelect then return end

		GuiService.SelectedObject = nil

		if GamepadService.GamepadCursorEnabled then
			GamepadService:DisableGamepadCursor()
		else
			GamepadService:EnableGamepadCursor(nil)
		end
	end)
end

function GamepadController:_SetupGamepadIcon(gamepadIcon)
	local function updateIcon()
		local buttonKeyCode = gamepadIcon:GetAttribute("KeyCode")
		if (not buttonKeyCode) or (buttonKeyCode == "") then return end

		local image = Constants.GamepadIcons[UserInputService:GetStringForKeyCode(buttonKeyCode)]

		if Device.GetUserDevice() == "Controller" then
			gamepadIcon.Image = image
			gamepadIcon.Visible = true
		else
			gamepadIcon.Image = ""
			gamepadIcon.Visible = false
		end
	end

	local iconTrove = Trove.new()

	updateIcon()

	iconTrove:Add(gamepadIcon:GetAttributeChangedSignal("KeyCode"):Connect(function()
		updateIcon()
	end))

	iconTrove:Add(Device.DeviceUpdated:Connect(function()
		updateIcon()
	end))

	iconTrove:Add(gamepadIcon.AncestryChanged:Connect(function()
		if not gamepadIcon.Parent then
			iconTrove:Clean()
		end
	end))
end

return GamepadController