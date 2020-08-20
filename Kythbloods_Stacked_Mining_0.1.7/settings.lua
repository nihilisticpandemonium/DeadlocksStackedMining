data:extend({
	{
        type = "bool-setting",
        name = "ky-overwrite-deadlock-stack-size",
        setting_type = "startup",
        default_value = false,
        order = "a"
	},
	{
        type = "int-setting",
        name = "ky-mining-stack-size",
        setting_type = "startup",
        default_value = 5,
        order = "b",
		minimum_value = 4,
		maximum_value = 128
    }
})
