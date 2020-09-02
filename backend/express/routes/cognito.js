'use strict';

const
	express = require('express'),
	axios = require('axios').default,
	qs = require('qs');

const signedIn = config => {
	const isDev = config.env === 'dev';

	const getTokens = async (code) => {
		const appClientId = config.aws.cognito.appClientId;
		const appClientSecret = config.aws.cognito.appClientSecret;
		const secret = Buffer.from(`${appClientId}:${appClientSecret}`).toString('base64');
		const data = {
			grant_type: 'authorization_code', // refresh_token or client_credentials.,
			client_id: appClientId,
			code: code,
			redirect_uri: config.aws.cognito.redirectUri,
		};
		const options = {
			headers: {
				'content-type': 'application/x-www-form-urlencoded',
				'Authorization': `Basic ${secret}`,
			},
		};

		const response = await axios.post(config.aws.cognito.OAuthUri, qs.stringify(data), options);
		return response.data;
	};

	return async (req, res) => {
		const code = req.query.code; // ex: 'a8f1491d-b1fa-44b6-9b9b-d30e06adffa9'

		if (isDev && !config.forceCognito) {

		} else {
			const tokens = await getTokens(code);
			console.log(tokens);
		}

		res.redirect('/');
	};
};

const signedOut = config => async (req, res) => {
	console.log(req.originalUrl);
	console.log(req.path);
	console.log(req.route);
	console.log(req.params);
	console.log(req.query);
	console.log(req.cookies);
	console.log(req.body);
	res.send('Logged out');
};

module.exports = (config) => {
	const
		router = express.Router();

	router.get('/auth/signedin', signedIn(config));
	router.get('/auth/signedout', signedOut(config));

	return router;
};
