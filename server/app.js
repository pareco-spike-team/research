'use strict';

const
	Path = require('path'),
	p3p = require('p3p'),
	bodyParser = require('body-parser'),
	compress = require('compression'),
	session = require('express-session'),
	helmet = require('helmet'),
	cookieParser = require('cookie-parser');


function setupExpress() {
	const
		express = require('express');

	let app = express();
	app.enable('trust proxy');
	app.use(compress());
	app.use(helmet());

	app.use(require("morgan")("short"));

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
			secure: true,
			sameSite: true,
			maxAge: 7 * ONE_DAY
		}
	}));

	app.use(p3p(p3p.recommended));
	app.use(cookieParser());

	return app;
}

function setupRoutes(app, config) {
	const
		routes = require('./routes/index.js');

	app.get('/*', function(req, res, next) {
		const ignore = /^\/(lib)|(css)|(js)|(img)|(api)|(fonts).*$/;
		if (ignore.test(req.originalUrl)) {
			next();
		} else {
			const path = Path.join(__dirname, '../dist/index.html');
			res.sendFile(path);
		}
	});

	routes(config, app);
}

function create(config) {
	let app = setupExpress();
	setupRoutes(app, config);

	return {
		start: app
	};
}

module.exports = create;
