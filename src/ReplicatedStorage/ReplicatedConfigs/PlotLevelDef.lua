local PlotLevelDef = {}

PlotLevelDef.MaxLevel = 6
PlotLevelDef.BaseCapacity = 5
PlotLevelDef.CostPerLevelSquared = 1_000 -- not used anymore, just keeping it in case some random shit still reads it
PlotLevelDef.UpgradeCosts = { 250_000, 5_000_000, 100_000_000, 5_000_000_000, 250_000_000_000 } -- scaled way up, max slots were too cheap and ppl had a billion dinos lagging

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

	return PlotLevelDef.UpgradeCosts[level]
end

return PlotLevelDef
