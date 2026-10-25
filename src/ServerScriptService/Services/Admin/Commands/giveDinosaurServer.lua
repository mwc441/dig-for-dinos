local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DirtSpawnerDef = require(ReplicatedStorage:WaitForChild("ReplicatedConfigs"):WaitForChild("DirtSpawnerDef"))
local DinosaurService = require(ServerScriptService.Services.Dinosaurs.DinosaurService)

local maxScale = 0
for _, spawnerInfo in pairs(DirtSpawnerDef.Table) do
	for _, scaleRange in ipairs(spawnerInfo.ScaleLootTable) do
		maxScale = math.max(maxScale, scaleRange.MaxScale)
	end
end

return function(_context, player, dinosaurId, scale, mutation)
	if scale <= 0 then
		return "Scale must be greater than 0."
	end

	if scale > maxScale then
		return `Scale can't be bigger than {maxScale}.`
	end

	local guid = DinosaurService:GiveDinosaur(player, dinosaurId, scale, mutation)
	if not guid then
		return "Could not give the dinosaur to " .. player.Name .. "."
	end

	return `Gave {player.Name} a {scale}x {mutation} {dinosaurId}.`
end
