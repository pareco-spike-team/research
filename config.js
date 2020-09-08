'use strict';

const
	nodeEnvironment = process.env.NODE_ENV,
	environment = process.env.ENVIRONMENT,
	env = environment || nodeEnvironment || "dev",
	FS = require('fs'),
	envConfig =
		(env === 'production') ?
			require('./config.production.json') :
			getDevConfig();

function getDevConfig() {
	const fileName = `config.${env}.json`;
	const path = `${__dirname}/${fileName}`;
	try {
		return JSON.parse(FS.readFileSync(path).toString());
	}
	catch (e) {
		if (e.code === "ENOENT") {
			if (env !== 'dev') { throw `Cannot find file ${fileName}`; }
			const devConfig = {
				"aws": {
					"profile": "profile",
					"account": "account",
					"region": "region",
					"cognito": {
						"userPoolId": "userPoolId",
						"appClientId": "appClientId",
						"appClientSecret": "appClientSecret",
						"baseUri": "baseUri"
					}
				},
				"queue": {
					"galnetArticleUpdate": "galnetArticleUpdate"
				},
				"neo": {
					"url": "bolt://localhost:7689",
					"user": "neo4j",
					"password": "put pwd here"
				},
				"forceCognito": false
			};
			FS.writeFileSync(path, JSON.stringify(devConfig, null, '\t'));
			return devConfig;
		}
	}
}


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

