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
			Type = "announcementColor",
			Name = "Color",
			Description = "RGB, #hex, or EasyVisuals effect such as Zebra or Rainbow",
			Default = Color3.fromRGB(255, 255, 255)
		}
	};
}
