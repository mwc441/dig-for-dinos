--!strict
-- created by derpmonster83
local DeviceUpdated = Instance.new("BindableEvent")
type ValidDevice = "Controller" | "Mobile" | "PC"
export type UserDeviceImpl = {
	DeviceUpdated: RBXScriptSignal,
	GetUserDevice: () -> ValidDevice,
	GetControllerType: () -> string,
	SetSelectedUI: (ui: GuiObject?) -> ()
}

-- Module table:
local UserDevice = {
	DeviceUpdated = DeviceUpdated.Event
} :: UserDeviceImpl

-- Loaded services
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GamepadService = game:GetService("GamepadService")

-- Constant variables
local LOCAL_PLAYER = Players.LocalPlayer

-- Private variables
local current_device: ValidDevice
local selected_ui
local visibility_conn: RBXScriptConnection?
local controller_type: ValidDevice  = "PC"

-- Private functions
local function set_ui()
	if current_device == "Controller" and selected_ui then
		-- don't do anything if already selected
		local curr_selected = GuiService.SelectedObject
		if curr_selected == selected_ui or
			(curr_selected ~= nil and curr_selected:IsDescendantOf(selected_ui)) then return end
		
		-- select
		GuiService:Select(selected_ui)
	else
		GuiService.SelectedObject = nil
		GamepadService:DisableGamepadCursor()
	end
end

local function set_device(input: Enum.UserInputType)
	local new_device: ValidDevice
	if input == Enum.UserInputType.Touch then
		new_device = "Mobile"
	elseif input.Name:find("Gamepad") then
		new_device = "Controller"
	else
		new_device = "PC"
	end
	
	if new_device ~= current_device then
		current_device = new_device
		set_ui()
		
		DeviceUpdated:Fire(new_device)
	end
end

-- Global methods
function UserDevice.GetUserDevice()
	return current_device
end

function UserDevice.SetSelectedUI(ui)
	selected_ui = ui
	
	if visibility_conn ~= nil then
		visibility_conn:Disconnect()
		visibility_conn = nil
	end
	
	if ui ~= nil then
		visibility_conn = ui:GetPropertyChangedSignal("Visible"):Connect(function()
			UserDevice.SetSelectedUI()
		end)
	end
	set_ui()
end

-- Setup:
UserInputService.LastInputTypeChanged:Connect(set_device)
UserInputService.WindowFocused:Connect(set_ui)
set_device(UserInputService:GetLastInputType())

return UserDevice