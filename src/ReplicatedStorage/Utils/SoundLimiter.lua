local SoundLimiter = {}
SoundLimiter.__index = SoundLimiter

function SoundLimiter.new()
	return setmetatable({
		_Playing = {}, -- [SoundId] = {entry, entry, ...}
	}, SoundLimiter)
end

function SoundLimiter:CanPlay(soundId: string, position: Vector3, radius: number): boolean
	local entries = self._Playing[soundId]
	if not entries then
		return true
	end

	local now = os.clock()
	local radiusSquared = radius * radius

	for i = #entries, 1, -1 do
		local entry = entries[i]

		local offset = entry.Position - position

		if (offset:Dot(offset) <= radiusSquared) and (entry.Expires > now) then
			return false
		end
	end

	if #entries == 0 then
		self._Playing[soundId] = nil
	end

	return true
end

function SoundLimiter:Register(sound: Sound, cframe: CFrame, cooldown: number)
	local soundId = sound.SoundId
	cooldown = cooldown or 0

	local entries = self._Playing[soundId]
	if not entries then
		entries = {}
		self._Playing[soundId] = entries
	end

	local entry = {
		Sound = sound,
		Position = cframe.Position,
		Expires = os.clock() + cooldown
	}

	table.insert(entries, entry)

	local cleaned = false
	local connection
	local cleanupTask

	local function cleanup()
		if cleaned then
			return
		end

		cleaned = true

		if connection then
			connection:Disconnect()
		end

		if cleanupTask then
			task.cancel(cleanupTask)
			cleanupTask = nil
		end

		for i = #entries, 1, -1 do
			if entries[i] == entry then
				table.remove(entries, i)
				break
			end
		end

		if #entries == 0 then
			self._Playing[soundId] = nil
		end
	end

	if cooldown < math.huge then
		cleanupTask = task.delay(cooldown, function()
			cleanupTask = nil
			cleanup()
		end)
	end

	connection = sound.AncestryChanged:Connect(function()
		if not sound.Parent then
			cleanup()
		end
	end)

	return cleanup
end

return SoundLimiter
