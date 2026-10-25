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
			Type = "announcementColor",
			Name = "Color",
			Description = "RGB, #hex, or EasyVisuals effect such as Zebra or Rainbow",
			Default = Color3.fromRGB(255, 255, 255)
		},
	};
}
