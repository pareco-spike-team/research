'use strict';

const
	path = require('path');

const sendIndexFile = (req, res) => {
	res.sendFile(path.join(__dirname, '../dist/index.html'));
};

const addRoutes = (router) => {
	router.get("/", sendIndexFile);
	router.use('/', require('./api.js')());
};


// function errorHandler(err, req, res, next) {
// 	res.status(err.errorCode).json({ success: false, data: { message: err.message, route: err.route } });
// }

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
	var express = require('express');
	var router = express.Router();

	addRoutes(router);
	app.use(express.static('./dist'));
	app.use(router);
	// app.use(errorHandler);

	printRoutes(router);
};
