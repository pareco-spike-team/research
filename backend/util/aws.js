'use strict';

const
	config = require('../../config.js'),
	https = require('https');

const sslAgent = new https.Agent({
	keepAlive: true,
	maxSockets: 50,
	rejectUnauthorized: true
});

module.exports = (() => {
	if (config.aws.profile && process.env.INSTANCE_ID == null) {
		process.env.AWS_PROFILE = config.aws.profile;
	}
	const AWS = require('aws-sdk');
	AWS.config.update({ region: config.aws.region });
	AWS.config.update({ httpOptions: { agent: sslAgent } });
	return AWS;
})();
