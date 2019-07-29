'use strict';

const
	mapToReturn = require('./helper/mapToReturn.js'),
	{ getDriver, runQuery } = require('../../util/neoHelper.js');

async function searchArticles(tags, filter) {
	const driver = getDriver();
	try {
		const s = driver.session();
		const buildMatch = xs => {
			return '(?muis)' + (
				xs.
					split(',').
					map(x => x.trim()).
					map(x =>
						(x.length >= 4) ?
							`.*${(x.toLowerCase())}.*` :
							`${(x.toLowerCase())}`).
					join('|'));
		};
		const tagQuery =
			tags ?
				runQuery(s)
					("MATCH (article:Article)-[:Tag]->(tag:Tag) WHERE tag.tag =~ {tag} RETURN article, tag")
					({ tag: buildMatch(tags) }) :
				Promise.resolve([]);
		const articleQuery =
			filter ?
				runQuery(s)
					("MATCH (article:Article) WHERE article.title =~ {article} OR article.text =~ {article} RETURN article")
					({ article: buildMatch(filter) }) :
				Promise.resolve([]);

		const [tagsResult, articleResult] = await Promise.all([tagQuery, articleQuery]);

		const articleMap =
			new Map(articleResult.map(x => {
				x.tags = [];
				delete x.tag;
				return [x.article.id, x];
			}));

		const result = mapToReturn(articleMap, tagsResult);
		return [...result.values()];
	} finally {
		driver.close();
	}
}

module.exports = searchArticles;
