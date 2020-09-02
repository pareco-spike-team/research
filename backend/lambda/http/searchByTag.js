'use strict';

const
	action = require('../helpers/lambdaHttp.js'),
	searchByTag = require('../../api/searchByTag.js');

function get(event /*, context*/) {
	action(async () => {
		const filter = event.queryStringParameters ? event.queryStringParameters.filter : null;
		return await searchByTag(filter);
	});

}

module.exports = {
	get
};
