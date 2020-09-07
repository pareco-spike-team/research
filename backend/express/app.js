'use strict';

const
	p3p = require('p3p'),
	bodyParser = require('body-parser'),
	compress = require('compression'),
	session = require('express-session'),
	helmet = require('helmet'),
	routes = require('./routes/index.js');


function setupExpress(env) {
	const
		express = require('express');

	let app = express();
	app.enable('trust proxy');
	app.use(compress());
	app.use(helmet());

	app.use(require("morgan")("short"));
	app.enable('trust proxy');


	app.use(bodyParser.urlencoded({ extended: true }));
	app.use(bodyParser.json({ limit: '5mb' }));

	const ONE_HOUR = 60 * 60 * 1000;
	const ONE_DAY = 24 * ONE_HOUR;
	app.use(session({
		name: 'galnetpedia',
		secret: 'dont_tell_anyone! It`s a secret!',
		saveUninitialized: false,
		resave: true,
		rolling: true,

		cookie: {
			secure: env !== 'dev',
			sameSite: true,
			maxAge: 7 * ONE_DAY
		}
	}));

	app.use(p3p(p3p.recommended));

	return app;
}

function create(config) {
	let app = setupExpress(config.env);
	routes(config, app);

	return {
		start: app
	};
}

module.exports = create;
