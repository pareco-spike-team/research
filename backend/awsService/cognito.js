'use strict';

const
	axios = require('axios').default,
	qs = require('qs');


const nameValueArrayToObject = arr => {
	return arr.reduce((acc, x) => {
		const name =
			x.Name.
				split('_').
				map((s) =>
					s.slice(0, 1).toUpperCase() + s.slice(1).toLowerCase()
				).
				join('');
		acc[name] = x.Value;
		return acc;
	}, {});
};

module.exports = (config, cognito) => {

	const getTokensByCode = async (code, redirectUri) => {
		const appClientId = config.aws.cognito.appClientId;
		const appClientSecret = config.aws.cognito.appClientSecret;
		const secret = Buffer.from(`${appClientId}:${appClientSecret}`).toString('base64');

		const data = {
			grant_type: 'authorization_code', // refresh_token or client_credentials.,
			client_id: appClientId,
			code: code,
			redirect_uri: redirectUri,
		};
		const options = {
			headers: {
				'content-type': 'application/x-www-form-urlencoded',
				'Authorization': `Basic ${secret}`,
			},
		};

		const url = `${config.aws.cognito.baseUri}/oauth2/token`;
		const response = await axios.post(url, qs.stringify(data), options);
		return response.data;
	};

	const getUser = async (accessToken) => {
		const params = {
			AccessToken: accessToken
		};
		const result = await cognito.getUser(params).promise();
		const cognitoUser = { username: result.Username, ...nameValueArrayToObject(result.UserAttributes) };

		/* Example cognitoUSer
		{
			"Sub": "691a0d91-9432-402d-bd44-ac0364f99e8c",
			"PhoneNumberVerified": "true",
			"PhoneNumber": "+467012345678",
			"GivenName": "Foo",
			"FamilyName": "Barsson",
			"Email": "foo.bar@gmail.com"
		}
		*/

		return cognitoUser;
	};

	const adminGetUser = async (sub) => {
		const params = {
			UserPoolId: config.aws.cognito.userPoolId,
			Username: sub
		};

		const result = await cognito.adminGetUser(params).promise();
		return { ...result, UserAttributes: nameValueArrayToObject(result.UserAttributes) };
	};

	const getGroupsForUser = async (username) => {
		const params = {
			UserPoolId: config.aws.cognito.userPoolId,
			Username: username,
			Limit: 20
		};
		const result = await cognito.adminListGroupsForUser(params).promise();
		return result.Groups;
	};

	return {
		getUser,
		adminGetUser,
		getGroupsForUser,
		getTokensByCode
	};
};
