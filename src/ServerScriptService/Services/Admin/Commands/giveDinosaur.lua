local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MutationsEnum = require(ReplicatedStorage:WaitForChild("Enums"):WaitForChild("Mutations"))

return {
	Name = "giveDinosaur";
	Aliases = {};
	Description = "Give a dinosaur to a player.";
	Group = "Custom Commands";
	Args = {
		{
			Type = "player";
			Name = "Player";
			Description = "Player to receive the dinosaur."
		},
		{
			Type = "dinosaurId";
			Name = "Dinosaur";
			Description = "Dinosaur ID to give."
		},
		{
			Type = "number";
			Name = "Scale";
			Description = "Dinosaur scale (defaults to 1).";
			Default = 1
		},
		{
			Type = "mutation";
			Name = "Mutation";
			Description = "Dinosaur mutation (defaults to Admin).";
			Default = MutationsEnum.Admin
		}
	};
}
