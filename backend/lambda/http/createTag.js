'use strict';

const
	action = require('../helpers/lambdaHttp.js'),
	createTag = require('../../api/createTag.js');


async function get(event /*, context */) {
	action(async () => {
		const name = event.queryStringParameters ? event.queryStringParameters.tagName : null;
		return await createTag(name);
	});
}

module.exports = {
	get
};
