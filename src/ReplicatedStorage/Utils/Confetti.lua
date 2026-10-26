local RunService = game:GetService("RunService")

local Confetti = {}

local rng = Random.new()
local gravity = Vector2.new(0, 650)
local colors = {
	Color3.fromRGB(255, 78, 86),
	Color3.fromRGB(255, 184, 64),
	Color3.fromRGB(255, 235, 82),
	Color3.fromRGB(95, 220, 126),
	Color3.fromRGB(75, 190, 255),
	Color3.fromRGB(157, 112, 255),
	Color3.fromRGB(255, 127, 205),
}

local function getFadeTargets(gui: GuiObject)
	local targets = {}

	local function addTargets(object: Instance)
		if object:IsA("GuiObject") then
			table.insert(targets, {Object = object, Property = "BackgroundTransparency", Start = object.BackgroundTransparency})

			if object:IsA("ImageLabel") or object:IsA("ImageButton") then
				table.insert(targets, {Object = object, Property = "ImageTransparency", Start = object.ImageTransparency})
			elseif object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
				table.insert(targets, {Object = object, Property = "TextTransparency", Start = object.TextTransparency})
				table.insert(targets, {Object = object, Property = "TextStrokeTransparency", Start = object.TextStrokeTransparency})
			end
		elseif object:IsA("UIStroke") then
			table.insert(targets, {Object = object, Property = "Transparency", Start = object.Transparency})
		end
	end

	addTargets(gui)
	for _, descendant in gui:GetDescendants() do
		addTargets(descendant)
	end

	return targets
end

-- origin is a pixel position relative to parent. If nil, each piece starts
-- at a random point inside parent. Angles are in degrees: 0 points right,
-- 90 points up, and 180 points left.
-- If templates is provided, each piece clones a random GuiObject from it.
-- minLifetime and maxLifetime are in seconds.
function Confetti.Burst(
	origin: Vector2?,
	parent: GuiObject | ScreenGui,
	count: number?,
	minAngle: number?,
	maxAngle: number?,
	templates: {GuiObject}?,
	minLifetime: number?,
	maxLifetime: number?
)
	count = math.max(0, math.floor(count or 40))
	minAngle = minAngle or 0
	maxAngle = maxAngle or 360
	minLifetime = minLifetime or 1.2
	maxLifetime = maxLifetime or 1.8

	if count == 0 then return end

	local pieces = {}
	local parentSize = parent.AbsoluteSize

	for _ = 1, count do
		local position = origin or Vector2.new(
			rng:NextNumber(0, parentSize.X),
			rng:NextNumber(0, parentSize.Y)
		)
		local angle = math.rad(rng:NextNumber(minAngle, maxAngle))
		local speed = rng:NextNumber(250, 450)
		local gui: GuiObject

		if templates and #templates > 0 then
			gui = templates[rng:NextInteger(1, #templates)]:Clone() :: GuiObject
		else
			local frame = Instance.new("Frame")
			frame.Name = "Confetti"
			frame.Size = UDim2.fromOffset(rng:NextInteger(4, 8), rng:NextInteger(7, 13))
			frame.BackgroundColor3 = colors[rng:NextInteger(1, #colors)]
			frame.BorderSizePixel = 0
			frame.ZIndex = 100000
			frame.Rotation = rng:NextNumber(0, 360)
			gui = frame
		end

		gui.AnchorPoint = Vector2.new(0.5, 0.5)
		gui.Position = UDim2.fromOffset(position.X, position.Y)
		gui.Visible = true
		gui.Parent = parent

		table.insert(pieces, {
			Gui = gui,
			FadeTargets = getFadeTargets(gui),
			Position = position,
			Velocity = Vector2.new(math.cos(angle), -math.sin(angle)) * speed,
			Spin = rng:NextNumber(-360, 360),
			Age = 0,
			Lifetime = rng:NextNumber(minLifetime, maxLifetime),
		})
	end

	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		for index = #pieces, 1, -1 do
			local piece = pieces[index]
			piece.Age += dt

			if piece.Age >= piece.Lifetime or not piece.Gui.Parent then
				piece.Gui:Destroy()
				table.remove(pieces, index)
			else
				piece.Position += piece.Velocity * dt + gravity * (0.5 * dt * dt)
				piece.Velocity += gravity * dt
				piece.Gui.Position = UDim2.fromOffset(piece.Position.X, piece.Position.Y)
				piece.Gui.Rotation = piece.Gui.Rotation + piece.Spin * dt

				local fade = math.clamp((piece.Age / piece.Lifetime - 0.65) / 0.35, 0, 1)
				for _, target in piece.FadeTargets do
					target.Object[target.Property] = target.Start + (1 - target.Start) * fade
				end
			end
		end

		if #pieces == 0 then
			connection:Disconnect()
		end
	end)
end

return Confetti
