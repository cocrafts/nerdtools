return {
	setup = {
		on_attach = function(client, buffer)

		end,
		settings = {
			["rust-analyzer"] = {
				checkOnSave = {
					command = "clippy",
				},
			},
		},
	},
	formatter = {

	},
	linter = {

	},
}

