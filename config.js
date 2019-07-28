'use strict';

const
	nodeEnvironment = process.env.NODE_ENV,
	environment = process.env.ENVIRONMENT,
	env = nodeEnvironment || environment || "dev",
	prodConfig = require('./config.prod.js'),
	devConfig = require('./config.dev.js'),
	envConfig = (env === 'prod' || env === 'production') ? prodConfig : devConfig;


module.exports = (() => {
	console.log(`NODE_ENV: '${nodeEnvironment}'. ENVIRONMENT: '${environment}'. RESULT: '${env}'`);
	console.log(`NODE_ENV: '${nodeEnvironment}'. ENVIRONMENT: '${environment}'. RESULT: '${env}'`);
	return {
		env: env,
		neoUrl: "bolt://localhost:7689",
		neoUser: 'neo4j',
		neoPassword: process.env.NEO_PWD || process.argv.slice(-1)[0] || 'is_this_the_password?',
		...envConfig
	};
})();
