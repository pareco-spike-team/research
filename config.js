'use strict';

const
	nodeEnvironment = process.env.NODE_ENV,
	environment = process.env.ENVIRONMENT,
	env = environment || nodeEnvironment || "dev",
	envConfig =
		(env === 'production') ?
			require('./config.production.json') :
			require('./config.dev.json');


module.exports = (() => {
	console.log(`NODE_ENV: '${nodeEnvironment}'. ENVIRONMENT: '${environment}'. RESULT: '${env}'`);
	return {
		env: env,
		neo: {
			url: "bolt://localhost:7689",
			user: "neo4j",
			password: process.env.NEO_PWD ||
				(process.argv.length > 2 ? process.argv.slice(-1)[0] : null) ||
				'is_this_the_password?',
		},
		...envConfig
	};
})();
