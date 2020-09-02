'use strict';

const
	action = require('../helpers/lambdaHttp.js'),
	getArticlesWithTag = require('../../api/getArticlesWithTag.js');


async function get(event /*, context */) {
	action(async () => {
		const tagId = event.pathParameters.tagId;
		return await getArticlesWithTag(tagId);
	});
}

module.exports = {
	get
};
