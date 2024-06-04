const { copyAssets } = require('./vendor/webpack');

module.exports = {
	publicPath: () => process.env.PUBLIC_URL || '/',
	keepPreviousBuild: () => true,
	buildId: () => 'app',
	webpackMiddlewares: [copyAssets],
	moduleAlias: {
		global: {
			'react-native$': 'react-native-web',
		},
	},
};
