const { resolve } = require('path');
const CopyPlugin = require('copy-webpack-plugin');

const copyAssets = (config) => {
	config.module.rules[1].use[1] = {
		loader: 'css-loader',
		options: { url: false },
	};

	config.plugins.push(
		new CopyPlugin({
			patterns: [
				{
					from: resolve(process.cwd(), 'assets/'),
					to: './',
					filter: (uri) => {
						const isTemplate = uri.endsWith('.ejs') || uri.endsWith('.sass');
						return !isTemplate;
					},
				},
			],
		}),
	);

	return config;
};

module.exports = {
	copyAssets,
};
