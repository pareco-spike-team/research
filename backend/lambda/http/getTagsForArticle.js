'use strict';

const
	action = require('../helpers/lambdaHttp.js'),
	getTagsForArticle = require('../../api/getTagsForArticle.js');


async function get(event /*, context*/) {
	action(async () => {
		const articleId = event.pathParameters.articleId;
		const includeArticles =
			event.queryStringParameters ?
				event.queryStringParameters.includeArticles :
				null;

		return await getTagsForArticle(articleId, includeArticles);
	});

}

module.exports = {
	get
};
