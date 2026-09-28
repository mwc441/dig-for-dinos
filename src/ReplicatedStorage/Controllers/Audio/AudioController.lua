local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local External = ReplicatedStorage:WaitForChild("External")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local Enums = ReplicatedStorage:WaitForChild("Enums")
local SettingsEnum = require(Enums:WaitForChild("Settings"))
local Knit = require(External:WaitForChild("Knit"))

local AudioController = {
	Name = "AudioController",
	_SettingsController = nil,
	_CurrentBackgroundSound = nil,
	_PreviousSound = nil,
	_MusicVolume = 1
}

function AudioController:KnitInit()
	self._BackgroundMusicOriginalVolume = Sounds.BackgroundMusic.Volume
	self._SoundEffectOriginalVolume = Sounds.SFX.Volume

	self:_CacheSoundVolumes()

	Sounds.DescendantAdded:Connect(function(sound)
		if not sound:IsA("Sound") then
			return
		end

		self:_CacheSoundVolume(sound)
	end)
end

function AudioController:KnitStart()
	self._SettingsController = require(ReplicatedStorage.Controllers.Settings.SettingsController)

	self._SettingsController:WaitForSettings()

	self._SettingsController.SettingUpdated:Connect(function(settingId, value)
		if settingId == SettingsEnum.MusicVolume then
			self:_SetMusicVolume(value)
		end

		if settingId == SettingsEnum.SoundEffectVolume then
			self:_SetSoundEffectVolume(value)
		end
	end)

	self:_SetMusicVolume(self._SettingsController:GetSetting(SettingsEnum.MusicVolume))
	self:_SetSoundEffectVolume(self._SettingsController:GetSetting(SettingsEnum.SoundEffectVolume))

	self:PlayBackgroundMusic(Sounds.BackgroundMusic)
end

function AudioController:_SetMusicVolume(volume)
	self._MusicVolume = volume

	Sounds.BackgroundMusic.Volume = self._BackgroundMusicOriginalVolume * self._MusicVolume
end

function AudioController:_SetSoundEffectVolume(volume)
	self._SoundEffectVolume = volume

	Sounds.SFX.Volume = self._SoundEffectOriginalVolume * self._SoundEffectVolume
end

function AudioController:_CacheSoundVolumes()
	for _, descendant in pairs(Sounds:GetDescendants()) do
		if descendant:IsA("Sound") then
			self:_CacheSoundVolume(descendant)
		end
	end
end

function AudioController:_CacheSoundVolume(sound)
	sound:SetAttribute("OriginalVolume", sound.Volume)
end

function AudioController:ResumeBackgroundMusic()
	if self._CurrentBackgroundSound then
		self._CurrentBackgroundSound:Resume()
		self:_TweenInSound(self._CurrentBackgroundSound)
	end
end

function AudioController:PauseBackgroundMusic()
	if self._CurrentBackgroundSound then
		local sound : Sound = self._CurrentBackgroundSound
		self:_TweenOutSound(self._CurrentBackgroundSound, function()
			sound:Pause()
		end)
	end
end

function AudioController:PlayBackgroundMusic(sound)
	if self._PlayTask then
		task.cancel(self._PlayTask)
	end

	self._PlayTask = task.spawn(function()
		self:StopBackgroundMusic()

		if sound:IsA("Folder") or sound:IsA("SoundGroup") then
			local sounds = sound:GetChildren()

			-- Don't replay last song, ever...
			local playSound = sounds[math.random(1, #sounds)]
			while (#sounds > 1) and (playSound == self._PreviousSound) do
				playSound = sounds[math.random(1, #sounds)]
			end

			playSound.Looped = false
			self:_PlayBackgroundSound(playSound)

			self._BackgroundEndedConnect = playSound.Ended:Connect(function()
				self._CurrentBackgroundSound = nil
				self:PlayBackgroundMusic(sound)
			end)
		elseif sound:IsA("Sound") then
			sound.Looped = true
			self:_PlayBackgroundSound(sound)
		end
	end)
end

function AudioController:_PlayBackgroundSound(sound)
	self._CurrentBackgroundSound = sound
	self._PreviousSound = sound

	sound.TimePosition = 0
	sound:Play()

	self:_TweenInSound(sound)
	self:_BlurCurrentSound()
end

function AudioController:StopBackgroundMusic()
	if self._PlayTask then
		task.cancel(self._PlayTask)
	end
	self._PlayTask = nil

	if self._BackgroundEndedConnect then
		self._BackgroundEndedConnect:Disconnect()
	end
	self._BackgroundEndedConnect = nil

	if self._CurrentBackgroundSound then
		local currentSound = self._CurrentBackgroundSound

		self:_TweenOutSound(self._CurrentBackgroundSound, function()
			currentSound:Stop()
		end)

		self:_UnblurCurrentSound()

		self._CurrentBackgroundSound = nil

		if currentSound.Playing then
			currentSound.Stopped:Wait()
		end
	end
end

function AudioController:_TweenInSound(sound)
	local tweenInfo = TweenInfo.new(1)

	sound.Volume = 0

	local tween = TweenService:Create(sound, tweenInfo, {
		Volume = sound:GetAttribute("OriginalVolume")
	})

	self._Tween = tween

	tween:Play()
end

function AudioController:_TweenOutSound(sound, callback)
	local tweenInfo = TweenInfo.new(1)

	local tween = TweenService:Create(sound, tweenInfo, {
		Volume = 0
	})

	tween:Play()

	self._Tween = tween

	local connect
	connect = tween.Completed:Connect(function(playbackState)
		connect:Disconnect()

		if playbackState == Enum.PlaybackState.Completed then
			if callback then
				callback()
			end
		end
	end)
end

function AudioController:BlurSound(totalBlurTime)
	if self._Blurred then
		return
	end

	self._Blurred = true

	self:_BlurCurrentSound(true, totalBlurTime)
end

function AudioController:UnblurSound(toTween, totalTime)
	if not self._Blurred then
		return
	end

	self._Blurred = false

	self:_UnblurCurrentSound(toTween, totalTime)
end

function AudioController:_BlurCurrentSound(toTween, totalBlurTime)
	if not self._Blurred then
		return
	end

	if not self._CurrentBackgroundSound then
		return
	end

	local blurEffect = self._CurrentBackgroundSound:FindFirstChild("BlurEffect")
	if blurEffect then
		return
	end

	local newEquilizerEffect = Instance.new("EqualizerSoundEffect")
	newEquilizerEffect.HighGain = 0
	newEquilizerEffect.MidGain = 0
	newEquilizerEffect.LowGain = 0

	newEquilizerEffect.Name = "BlurEffect"
	newEquilizerEffect.Parent = self._CurrentBackgroundSound

	local highGain = -80
	local midGain = -15
	local lowGain = 10

	if toTween then
		local tweenInfo = TweenInfo.new(totalBlurTime)
		local tween = TweenService:Create(newEquilizerEffect, tweenInfo, {
			HighGain = highGain,
			MidGain = midGain,
			LowGain = lowGain
		})
		tween:Play()
	else
		newEquilizerEffect.HighGain = highGain
		newEquilizerEffect.MidGain = midGain
		newEquilizerEffect.LowGain = lowGain
	end
end

function AudioController:_UnblurCurrentSound(toTween, totalTime)
	if not self._CurrentBackgroundSound then
		return
	end

	local blurEffect = self._CurrentBackgroundSound:FindFirstChild("BlurEffect")
	if not blurEffect then
		return
	end

	blurEffect.Name = "_TOBEDESTROYED"

	if toTween then
		local tweenInfo = TweenInfo.new(totalTime)
		local tween = TweenService:Create(blurEffect, tweenInfo, {
			HighGain = 0,
			MidGain = 0,
			LowGain = 0
		})
		tween:Play()

		local connect
		connect = tween.Completed:Connect(function()
			connect:Disconnect()
			blurEffect:Destroy()
		end)
	else
		blurEffect:Destroy()
	end
end

return AudioController