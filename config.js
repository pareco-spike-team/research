'use strict';

const
	fs = require('fs'),
	nodeEnvironment = process.env.NODE_ENV,
	env = nodeEnvironment || "dev",
	envConfigFile = `${__dirname}/config.${env}.json`;

const envCfg = (fs.existsSync(envConfigFile)) ?
	fs.readFileSync(envConfigFile) :
	"{}";

module.exports = {
	env: env,
	neoUrl: "bolt://localhost:7689",
	neoUser: 'neo4j',
	neoPassword: process.env.NEO_PWD || process.argv.slice(-1)[0] || 'is_this_the_password?',
	...(JSON.parse("" + envCfg))
};
