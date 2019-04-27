'use strict';

const
	Path = require('path');

const sendIndexFile = (req, res) => {
	res.sendFile(Path.join(__dirname, '../../dist/index.html'));
};

const addRoutes = (router) => {
	router.get("/", sendIndexFile);
	router.use('/', require('./api.js')());
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

module.exports = function(config, app) {
	const express = require('express');
	const router = express.Router();
	const staticFolder = Path.join(__dirname, "..", "..", "dist");
	addRoutes(router);
	app.use(express.static(staticFolder));
	app.use(router);

	printRoutes(router);
};
