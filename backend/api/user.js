'use strict';

const
	config = require('../../config.js'),
	AWS = require('../util/aws.js'),
	Cognito = new AWS.CognitoIdentityServiceProvider({ apiVersion: '2016-04-18' }),
	cognito = require('../awsService/cognito.js')(config, Cognito);


async function refresh(cognitoSession) {
	if (cognitoSession == null) {
		return { error: 'not-logged-in' };
	}
	const user = await cognito.getUser(cognitoSession.access_token);
	return { result: user };
}

module.exports = {
	refresh
};
