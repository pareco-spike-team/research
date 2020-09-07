'use strict';

const
	express = require('express'),
	axios = require('axios').default,
	qs = require('qs'),
	AWS = require('../../util/aws.js'),
	Cognito = new AWS.CognitoIdentityServiceProvider({ apiVersion: '2016-04-18' }),
	cognitoFactory = require('../../awsService/cognito.js');


const signedIn = config => {
	const isDev = config.env === 'dev';
	const cognito = cognitoFactory(config, Cognito);

	const getTokens = async (code, redirectUri) => {
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

	return async (req, res) => {
		const code = req.query.code; // ex: 'a8f1491d-b1fa-44b6-9b9b-d30e06adffa9'

		try {
			if (isDev && !config.forceCognito) {

			} else {
				const redirectUri = `${req.protocol}://${req.headers.host}/auth/signedin`;
				const tokens = await getTokens(code, redirectUri);
				const now = Date.now();
				req.session.cognito = {
					createdAt: new Date(now),
					expiresAt: new Date(now + 1000 * tokens.expires_in),
					...tokens
				};
				const user = await cognito.getUser(tokens.access_token);
				req.session.user = user;
			}

			res.redirect('/');
		} catch (err) {
			console.error(err);
			if (err && err.response && err.response.status === 400) {
				res.status(400).send("Bad Request");
				return;
			}
			res.status(500).send();
		}
	};
};

const signedOut = () => async (req, res) => {
	delete req.session.cognito;
	delete req.session.user;
	res.redirect("/");
};

const signIn = config => async (req, res) => {
	delete req.session.cognito;
	delete req.session.user;
	const redirectUri = `${req.protocol}://${req.headers.host}/auth/signedin`;
	const url =
		`${config.aws.cognito.baseUri}/login?client_id=${config.aws.cognito.appClientId}&response_type=code&scope=aws.cognito.signin.user.admin+email+openid+profile&redirect_uri=${redirectUri}`;
	res.redirect(url);
};

const signUp = config => async (req, res) => {
	const redirectUri = `${req.protocol}://${req.headers.host}/auth/signedin`;
	const url =
		`${config.aws.cognito.baseUri}/signup?client_id=${config.aws.cognito.appClientId}&response_type=code&scope=aws.cognito.signin.user.admin+email+openid+profile&redirect_uri=${redirectUri}`;
	res.redirect(url);
};

module.exports = (config) => {
	const
		router = express.Router();

	router.get('/auth/signedin', signedIn(config));
	router.get('/auth/signedout', signedOut());
	router.get('/auth/signin', signIn(config));
	router.get('/auth/signup', signUp(config));

	return router;
};
