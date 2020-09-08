'use strict';

const
	express = require('express');


const signedIn = (config, cognito) => {
	const isDev = config.env === 'dev';

	const getSignedInUser = async (protocol, host, code) => {
		if (isDev && !config.forceCognito) {

		} else {
			const redirectUri = `${protocol}://${host}/auth/signedin`;
			const tokens = await cognito.getTokensByCode(code, redirectUri);
			const now = Date.now();
			return {
				createdAt: new Date(now),
				expiresAt: new Date(now + 1000 * tokens.expires_in),
				...tokens
			};
		}
	};

	const getUserFromCognito = async (accessToken) => {
		const user = await cognito.getUser(accessToken);
		const groups = await cognito.getGroupsForUser(user.username);
		return { ...user, groups: groups.map(x => x.GroupName) };
	};

	return async (req, res) => {
		const code = req.query.code; // ex: 'a8f1491d-b1fa-44b6-9b9b-d30e06adffa9'

		try {
			const cognitoTokens = await getSignedInUser(req.protocol, req.headers.host, code);
			const user = await getUserFromCognito(cognitoTokens.access_token);
			req.session.cognito = cognitoTokens;
			req.session.user = user;

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

module.exports = (config, cognito) => {
	const
		router = express.Router();

	router.get('/auth/signedin', signedIn(config, cognito));
	router.get('/auth/signedout', signedOut());
	router.get('/auth/signin', signIn(config));
	router.get('/auth/signup', signUp(config));

	return router;
};
