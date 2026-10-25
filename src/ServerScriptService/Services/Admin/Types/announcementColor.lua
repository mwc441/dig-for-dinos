local ReplicatedStorage = game:GetService("ReplicatedStorage")

local presets = ReplicatedStorage:WaitForChild("External"):WaitForChild("EasyVisuals"):WaitForChild("Presets")
local effectNames = {}
for _, preset in ipairs(presets:GetDescendants()) do
	if preset:IsA("ModuleScript") then
		table.insert(effectNames, preset.Name)
	end
end
table.sort(effectNames)

local function parseRgb(text)
	local red, green, blue = text:match("^(%d+),(%d+),(%d+)$")
	red, green, blue = tonumber(red), tonumber(green), tonumber(blue)
	if red and green and blue and red <= 255 and green <= 255 and blue <= 255 then
		return Color3.fromRGB(red, green, blue)
	end
end

return function(registry)
	local findEffect = registry.Cmdr.Util.MakeFuzzyFinder(effectNames)

	registry:RegisterType("announcementColor", {
		Prefixes = "# hexColor3 ! brickColor3",
		Transform = function(text)
			return parseRgb(text) or text
		end,
		Validate = function(value)
			if typeof(value) == "Color3" then
				return true
			end
			return findEffect(value, true) ~= nil, "Use an RGB color, hex color, or EasyVisuals preset."
		end,
		Autocomplete = function(value)
			return type(value) == "string" and findEffect(value) or {}
		end,
		Parse = function(value)
			if typeof(value) == "Color3" then
				return value
			end
			return findEffect(value, true)
		end
	})
end
