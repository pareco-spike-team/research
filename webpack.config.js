'use strict';

const serverlessWebpack = require('serverless-webpack');

module.exports = {
	mode: serverlessWebpack.lib.options.stage === 'prod' ? 'production' : 'development',
	entry: serverlessWebpack.lib.entries,
	target: 'node',
	// stats: 'minimal'
};
