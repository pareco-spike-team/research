'use strict';

const
	Path = require('path'),
	staticFolder = Path.join(__dirname, "..", "..", "..", "dist"),
	AWS = require('../../util/aws.js'),
	Cognito = new AWS.CognitoIdentityServiceProvider({ apiVersion: '2016-04-18' }),
	cognitoFactory = require('../../awsService/cognito.js');

const sendIndexFile = (req, res) => {
	res.sendFile(Path.join(staticFolder, 'index.html'));
};

const addRoutes = (config, router) => {
	router.get('/ping', (req, res) => res.send('pong'));

	router.use("/", require('./auth.js')(config, cognitoFactory(config, Cognito)));
	router.use('/', require('./api.js')());
	router.get("/", sendIndexFile);
};

function printRoutes(router) {
	const printRoute = (r) => {
		if (r.path) {
			const m = Object.getOwnPropertyNames(r.methods).
				map(x => (x.toUpperCase() + '   ').substring(0, 6)).
				join(', ');
			console.log(`${m} ${r.path}`);
		}
		if (r.name === 'router') {
			r.handle.stack.forEach(printRoute);
		}
		if (r.route) {
			printRoute(r.route);
		}
	};
	router.stack.forEach(printRoute);
}

function addFakeUser(req) {
	req.session.cognito = {
		createdAt: new Date(),
		expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
	};
	req.session.user = {
		Nickname: "Tinfoil",
		GivenName: "Testy",
		FamilyName: "Tinfoil",
		Email: "tinfoil@localhost",
		EmailVerified: "true"
	};
}

module.exports = function (config, app) {
	const express = require('express');
	const router = express.Router();
	const isDev = config.env === 'dev';

	router.use("/*", (req, res, next) => {
		if (isDev && !config.forceCognito) {
			addFakeUser(req);
		}
		next();
	});
	addRoutes(config, router);
	app.use(express.static(staticFolder));
	app.use(router);

	printRoutes(router);
};

