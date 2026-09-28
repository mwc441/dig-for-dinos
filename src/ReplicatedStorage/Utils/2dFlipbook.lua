local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local External = ReplicatedStorage:WaitForChild("External")
local Signal = require(External:WaitForChild("Signal"))

export type Flipbook = {
	Play: (self: Flipbook) -> (),
	PlayTimes: (self: Flipbook, count: number) -> (),
	Stop: (self: Flipbook) -> (),
	PlayOnCooldown: (self: Flipbook, cooldown: number) -> (),
	Reset: (self: Flipbook) -> (),
	SetFPS: (self: Flipbook, fps: number) -> (),
	Destroy: (self: Flipbook) -> (),
	Started: Signal.Signal,
	Stopped: Signal.Signal,
	LoopCompleted: Signal.Signal
}

local Flipbook = {}
Flipbook.__index = Flipbook

function Flipbook.new(
	imageLabel: ImageLabel,
	imageSize: Vector2,
	tilesPerRow: number,
	totalTiles: number,
	fps: number?
): Flipbook

	local self = setmetatable({}, Flipbook)

	self.ImageLabel = imageLabel

	-- Extract pixel size
	local imageWidth = imageSize.X
	local imageHeight = imageSize.Y

	self.TilesPerRow = tilesPerRow
	self.TotalTiles = totalTiles
	self.FPS = fps or 60

	self.TotalRows = math.ceil(totalTiles / tilesPerRow)

	-- Compute tile size
	self.TileSize = Vector2.new(
		imageWidth / tilesPerRow,
		imageHeight / self.TotalRows
	)

	self.CurrentFrame = 0
	self.Playing = false
	self.Looped = true

	-- Loop control
	self._targetLoops = nil :: number?
	self._currentLoops = 0

	self._accum = 0
	self._conn = nil

	-- Apply rect size
	imageLabel.ImageRectSize = self.TileSize

	self.Started = Signal.new()
	self.LoopCompleted = Signal.new()
	self.Stopped = Signal.new()

	self._AncestryChangedConnect = imageLabel.AncestryChanged:Connect(function()
		if not imageLabel.Parent then
			self:Destroy()
		end
	end)

	return self
end

function Flipbook:_updateFrame()
	local frame = self.CurrentFrame

	if frame >= self.TotalTiles then
		self._currentLoops += 1

		self.LoopCompleted:Fire()

		-- Finite playback handling
		if self._targetLoops then
			if self._currentLoops >= self._targetLoops then
				-- Snap to last frame before stopping (optional but nice)
				self.CurrentFrame = self.TotalTiles - 1

				local x = self.CurrentFrame % self.TilesPerRow
				local y = math.floor(self.CurrentFrame / self.TilesPerRow)

				self.ImageLabel.ImageRectOffset = Vector2.new(
					x * self.TileSize.X,
					y * self.TileSize.Y
				)

				self:Stop()
				return
			end
		end

		-- Looping behavior
		if self.Looped or self._targetLoops then
			frame = 0
		else
			self:Stop()
			return
		end
	end

	self.CurrentFrame = frame

	local x = frame % self.TilesPerRow
	local y = math.floor(frame / self.TilesPerRow)

	self.ImageLabel.ImageRectOffset = Vector2.new(
		x * self.TileSize.X,
		y * self.TileSize.Y
	)
end

-- Plays the flipbook
function Flipbook:Play()
	if self.Playing then return end

	self.Playing = true

	self._conn = RunService.Heartbeat:Connect(function(dt)
		self._accum += dt

		local frameTime = 1 / self.FPS

		while self._accum >= frameTime do
			self._accum -= frameTime
			self.CurrentFrame += 1
			self:_updateFrame()
		end
	end)

	self:_updateFrame()

	self.Started:Fire()
end

-- Loops the flipbook a given amount of times
function Flipbook:PlayTimes(count: number)
	self._targetLoops = count
	self._currentLoops = 0
	self.CurrentFrame = 0
	self._accum = 0

	self:Play()
end

-- Stops the flipbook from playing
function Flipbook:Stop()
	if not self.Playing then return end
	self.Playing = false

	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end

	self.Stopped:Fire()
end

-- Plays the flipbook from start to finish, then pauses for the given cooldown
-- and repeats!
function Flipbook:PlayOnCooldown(cooldown: number)
	if self._cooldownConn then return end

	self._cooldownConn = task.spawn(function()
		while true do
			-- Play once
			self:PlayTimes(1)

			self.Stopped:Wait()

			-- Wait before playing
			task.wait(cooldown)
		end
	end)
end

-- Stops the flipbook from playing on the cooldown
function Flipbook:StopCooldown()
	if self._cooldownConn then
		task.cancel(self._cooldownConn)
		self._cooldownConn = nil
	end
end

-- Resets the flipbook to the first frame and first loop
function Flipbook:Reset()
	self.CurrentFrame = 0
	self._accum = 0
	self._currentLoops = 0
	self:_updateFrame()
end

-- Set the FPS of the flipbook
function Flipbook:SetFPS(fps: number)
	self.FPS = fps
end

function Flipbook:Destroy()
	self:Stop()
	self:StopCooldown()
	self.Started:Destroy()
	self.Stopped:Destroy()
	self.LoopCompleted:Destroy()
	self._AncestryChangedConnect:Disconnect()
	table.clear(self)
end

return Flipbook