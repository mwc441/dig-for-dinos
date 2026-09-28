return {
	Name = "globalReward";
	Aliases = {};
	Description = "Give a reward to all players across servers!";
	Group = "Custom Commands";
	Args = {
		{
			Type = "rewardType";
			Name = "Reward Type";
			Description = "The reward type. For Example: Stardust, Tickets, Galaxy, etc..."
		},

		{
			Type = "number",
			Name = "Amount",
			Description = "Number amount",
			Default = 1
		},

		{
			Type = "string",
			Name = "Announcement",
			Description = "Optional Announcement to tell players about the reward!",
			Optional = true
		},

		{
			Type = "color3",
			Name = "Color",
			Description = "Color of announcement",
			Default = Color3.fromRGB(255, 255, 255)
		}
	};
}