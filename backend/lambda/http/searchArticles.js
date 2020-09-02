'use strict';

const
	action = require('../helpers/lambdaHttp.js'),
	searchArticles = require('../../api/searchArticles.js');


async function get(event /*, context */) {
	action(async () => {
		const tagFilter =
			event.queryStringParameters ?
				event.queryStringParameters.tagFilter :
				null;
		const articleFilter =
			event.queryStringParameters ?
				event.queryStringParameters.articleFilter :
				null;

		return await searchArticles(tagFilter, articleFilter);
	});
}

module.exports = {
	get: get
};
