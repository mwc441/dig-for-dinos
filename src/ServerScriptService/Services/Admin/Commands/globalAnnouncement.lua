return {
	Name = "globalAnnouncement";
	Aliases = {};
	Description = "Make a global announcement to all players!";
	Group = "Custom Commands";
	Args = {
		{
			Type = "string";
			Name = "announcement";
			Description = "The announcement you wanna make! (Put quotation marks around your message \"Hello World!\")"
		},

		{
			Type = "color3",
			Name = "Color",
			Description = "Color of announcement message",
			Default = Color3.fromRGB(255, 255, 255)
		},
	};
}