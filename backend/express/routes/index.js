'use strict';

const
	Path = require('path'),
	staticFolder = Path.join(__dirname, "..", "..", "..", "dist");

const sendIndexFile = (req, res) => {
	res.sendFile(Path.join(staticFolder, 'index.html'));
};

const addRoutes = (config, router) => {
	router.get('/ping', (req, res) => res.send('pong'));

	router.use("/", require('./cognito.js')(config));
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

module.exports = function (config, app) {
	const express = require('express');
	const router = express.Router();

	addRoutes(config, router);
	app.use(express.static(staticFolder));
	app.use(router);

	printRoutes(router);
};
