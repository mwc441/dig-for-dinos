-- StateMachine.lua
local State = require(script.State)

export type State = State.State

export type StateMachine = {
	CurrentState: State?,

	SetState: (self: StateMachine, newState: State?) -> (),
	ClearState: (self: StateMachine) -> (),
	Destroy: (self: StateMachine) -> (),
}

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new()
	local self = setmetatable({}, StateMachine)

	self.CurrentState = nil
	self.Destroyed = false

	return self
end

function StateMachine:SetState(newState: State?)
	assert(not self.Destroyed, "StateMachine is destroyed")

	local oldState = self.CurrentState

	if oldState == newState then
		return
	end

	if oldState then
		oldState:Exit(newState)
	end

	self.CurrentState = newState

	if newState then
		newState:Enter(oldState)
	end
end

function StateMachine:ClearState()
	self:SetState(nil)
end

function StateMachine:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true

	self:ClearState()
end

return StateMachine