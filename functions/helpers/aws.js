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
	const AWS = require('aws-sdk');
	AWS.config.update({ region: config.awsRegion });
	AWS.config.update({ httpOptions: { agent: sslAgent } });
	return AWS;
})();
