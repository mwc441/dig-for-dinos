local ParticleTransparencyFader = {}
ParticleTransparencyFader.__index = ParticleTransparencyFader

-- Utility: builds a new NumberSequence faded toward 1 by alpha
local function ApplyAlpha(originalSeq: NumberSequence, alpha: number)
	local newKPs = {}

	for i, kp in ipairs(originalSeq.Keypoints) do
		-- from = original value
		-- to = 1 (completely invisible)
		local target = 1

		-- alpha moves original → 1
		local value = kp.Value + (target - kp.Value) * alpha

		local envelope = 0

		newKPs[i] = NumberSequenceKeypoint.new(kp.Time, value, envelope)
	end

	return NumberSequence.new(newKPs)
end

-- Constructor
function ParticleTransparencyFader.new(emitter: ParticleEmitter)
	local self = setmetatable({}, ParticleTransparencyFader)

	self.Emitter = emitter
	self.Original = emitter.Transparency -- store original NumberSequence

	return self
end

-- alpha: 0 → original
--        1 → fully invisible
function ParticleTransparencyFader:SetAlpha(alpha: number)
	alpha = math.clamp(alpha, 0, 1)
	self.Emitter.Transparency = ApplyAlpha(self.Original, alpha)
end

return ParticleTransparencyFader