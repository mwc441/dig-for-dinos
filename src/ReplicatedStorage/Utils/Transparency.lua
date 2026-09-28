--!strict

export type Transparency = {
	Hide: (self: Transparency) -> (),
	Restore: (self: Transparency) -> (),
	Destroy: (self: Transparency) -> (),
}

type StoredState = {
	Transparency: number?,
	Enabled: boolean?,
}

local Transparency = {}
Transparency.__index = Transparency

function Transparency.new(root: Instance): Transparency
	local self = setmetatable({}, Transparency)

	self._root = root
	self._states = {} :: {[Instance]: StoredState}
	self._hidden = false

	return self
end

local function processInstance(self, inst: Instance)
	if inst:IsA("BasePart") then
		self._states[inst] = {
			Transparency = inst.Transparency,
			CanCollide = inst.CanCollide
		}
		inst.Transparency = 1
		inst.CanCollide = false
	elseif inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") then
		self._states[inst] = {
			Enabled = inst.Enabled
		}
		inst.Enabled = false
	end
end

function Transparency:Hide()
	if self._hidden then return end
	self._hidden = true

	-- include root + all descendants
	processInstance(self, self._root)

	for _, inst in ipairs(self._root:GetDescendants()) do
		processInstance(self, inst)
	end
end

function Transparency:Restore()
	if not self._hidden then return end
	self._hidden = false

	for inst, state in pairs(self._states) do
		if inst:IsA("BasePart") then
			inst.Transparency = state.Transparency
			inst.CanCollide = state.CanCollide
		elseif (inst:IsA("BillboardGui") or inst:IsA("SurfaceGui")) then
			inst.Enabled = state.Enabled
		end
	end

	table.clear(self._states)
end

function Transparency:Destroy()
	self:Restore()
	table.clear(self._states)
	self._root = nil
end

return Transparency