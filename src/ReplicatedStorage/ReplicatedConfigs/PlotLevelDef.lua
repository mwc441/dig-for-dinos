local PlotLevelDef = {}

PlotLevelDef.MaxLevel = 6
PlotLevelDef.BaseCapacity = 5
PlotLevelDef.CostPerLevelSquared = 1_000 -- Temporary pricing until dinosaur income is balanced.

function PlotLevelDef.GetLevel(level)
	if type(level) ~= "number" then
		return 1
	end

	return math.clamp(math.floor(level), 1, PlotLevelDef.MaxLevel)
end

function PlotLevelDef.GetCapacity(level)
	return PlotLevelDef.BaseCapacity + PlotLevelDef.GetLevel(level) - 1
end

function PlotLevelDef.GetUpgradeCost(level)
	level = PlotLevelDef.GetLevel(level)
	if level >= PlotLevelDef.MaxLevel then
		return nil
	end

	return PlotLevelDef.CostPerLevelSquared * level * level
end

return PlotLevelDef
