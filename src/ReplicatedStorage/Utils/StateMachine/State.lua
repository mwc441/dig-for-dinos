export type State = {
	Name: string,

	Enter: (self: State, previousState: State?) -> (),
	Exit: (self: State, nextState: State?) -> (),

	Destroy: (self: State) -> (),
}

local State = {}
State.__index = State

function State.new(name: string)
	local self = setmetatable({}, State)

	self.Name = name

	return self
end

function State:Enter(previousState: State?)
	-- override
end

function State:Exit(nextState: State?)
	-- override
end

function State:Destroy()
	-- optional override
end

return State