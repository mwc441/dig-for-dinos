--!strict
export type BindingInfo = {
	KeyCodes: { Enum.KeyCode }?,
	Up: Enum.KeyCode?,
	Down: Enum.KeyCode?,
	Left: Enum.KeyCode?,
	Right: Enum.KeyCode?,
	Forward: Enum.KeyCode?,
	Backward: Enum.KeyCode?,
	UIButton: GuiButton?,
}

export type InputContextClass = {
	Instance: InputContext,
	Actions: {[string]: InputAction},

	NewAction: (
		self: InputContextClass,
		name: string,
		bindings: BindingInfo
	) -> InputAction,

	Enable: (self: InputContextClass) -> (),
	Disable: (self: InputContextClass) -> (),
	Destroy: (self: InputContextClass) -> (),
}

-- Helper to create binding
local function CreateBinding(action: InputAction, keyCode: Enum.KeyCode)
	local binding = Instance.new("InputBinding")
	binding.KeyCode = keyCode
	binding.Parent = action
end

local InputContextClass = {}
InputContextClass.__index = InputContextClass

-- Constructor
function InputContextClass.new(name: string, parent : Instance): InputContextClass
	local context = Instance.new("InputContext")
	context.Name = name
	context.Parent = parent

	local self = setmetatable({}, InputContextClass)

	self.Instance = context
	self.Actions = {}

	return self
end

-- Create new action inside this context
function InputContextClass:NewAction(name: string, bindings: BindingInfo): InputAction
	assert(not self.Actions[name], `Action "{name}" already exists`)

	local action = Instance.new("InputAction")
	action.Name = name
	action.Parent = self.Instance

	-- KeyCode binding
	if bindings.KeyCodes then
		for _, keycode in pairs(bindings.KeyCodes) do
			CreateBinding(action, keycode)
		end
	end

	if bindings.Up or bindings.Down or bindings.Left or bindings.Right or bindings.Forward or bindings.Backward then
		local binding = Instance.new("InputBinding")

		if bindings.Up then
			binding.Up = bindings.Up
		end

		if bindings.Down then
			binding.Down = bindings.Down
		end

		if bindings.Left then
			binding.Left = bindings.Left
		end

		if bindings.Right then
			binding.Right = bindings.Right
		end

		if bindings.Forward then
			binding.Forward = bindings.Forward
		end

		if bindings.Backward then
			binding.Backward = bindings.Backward
		end

		binding.Parent = action
	end

	-- UI Button binding
	if bindings.UIButton then
		local binding = Instance.new("InputBinding")
		binding.UIButton = bindings.UIButton
		binding.Parent = action
	end

	self.Actions[name] = action

	return action
end

function InputContextClass:Enable()
	self.Instance.Enabled = true
end

function InputContextClass:Disable()
	self.Instance.Enabled = false
end

function InputContextClass:Destroy()
	self.Instance:Destroy()
	table.clear(self.Actions)
end

return InputContextClass