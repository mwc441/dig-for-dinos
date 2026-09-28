return {
	Name = "giveReward";
	Aliases = {};
	Description = "Give a reward to a player!";
	Group = "Custom Commands";
	Args = {
		{
			Type = "rewardType";
			Name = "Reward Type";
			Description = "The reward type. For Example: Bricks, Crystals, etc..."
		},

		{
			Type = "number",
			Name = "Amount",
			Description = "Number amount"
		},

		{
			Type = "player",
			Name = "Player",
			Description = "Player to give the reward to!",
			Optional = true
		}
	};
}