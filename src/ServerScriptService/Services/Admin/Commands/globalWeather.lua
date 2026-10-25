return {
	Name = "globalWeather";
	Aliases = {};
	Description = "Start weather in every server.";
	Group = "Custom Commands";
	Args = {
		{
			Type = "weather";
			Name = "Weather";
			Description = "Weather ID, such as Admin, Gold, or Void."
		},
		{
			Type = "number";
			Name = "Duration";
			Description = "Duration in seconds (defaults to 10 minutes).";
			Optional = true
		}
	};
}
