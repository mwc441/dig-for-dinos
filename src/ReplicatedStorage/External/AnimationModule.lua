local AnimatorModule = {}
AnimatorModule.__index = AnimatorModule

local Animators = {}

function AnimatorModule.new(Animator : Animator)
	local self = setmetatable({}, AnimatorModule)
	self.Animator = Animator
	self.Animations = {} :: {[Animation] : AnimationTrack}

	Animators[Animator] = self

	Animator.Parent.AncestryChanged:Connect(function(p)
		if not p then
			Animators[Animator] = nil
		end
	end)

	Animator.AnimationPlayed:Connect(function()
		local animationTracks = Animator:GetPlayingAnimationTracks()
		local total = #animationTracks
		if total >= 256 then
			warn("ANIMATOR FULL " .. Animator.Parent.Parent.Name)
		end
	end)

	return self
end

function AnimatorModule.GetAnimator(Animator : Animator)
	local animator = Animators[Animator]
	if not animator then
		animator = AnimatorModule.new(Animator)
	end

	return animator
end

function AnimatorModule:InsertAnimation(Animation : Animation) : AnimationTrack
	if self.Animations[Animation] then
		return self.Animations[Animation]
	end

	self.Animations[Animation] = self.Animator:LoadAnimation(Animation) :: AnimationTrack

	return self.Animations[Animation]
end

function AnimatorModule:DestroyAnimationTrack(Animation : Animation)
	local track = self.Animations[Animation]
	if not track then
		return
	end

	track:Stop()
	track:Destroy()
	self.Animations[Animation] = nil
end

function AnimatorModule:GetAnimationTrack(Animation : Animation) : AnimationTrack
	return self.Animations[Animation]
end

function AnimatorModule:GetAnimationTracks() : {[Animation] : AnimationTrack}
	return self.Animations
end

return AnimatorModule