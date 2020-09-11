'use strict';

const
	mapper = require('../util/neoMapper.js'),
	{ getDriver, runQuery } = require('../util/neoHelper.js');

async function searchArticles(tags, filter) {
	const driver = getDriver();
	try {
		const session = driver.session();
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
				runQuery(session)
					("MATCH (article:Article)-[links:Tag]->(tag:Tag) WHERE tag.tag =~ {tag} RETURN article, tag, links")
					({ tag: buildMatch(tags) }) :
				Promise.resolve([]);
		const articleQuery =
			filter ?
				runQuery(session)
					("MATCH (article:Article) WHERE article.title =~ {article} OR article.text =~ {article} RETURN article")
					({ article: buildMatch(filter) }) :
				Promise.resolve([]);

		const [tagsResult, articleResult] = await Promise.all([tagQuery, articleQuery]);

		const result =
			mapper().
				map(articleResult).
				map(tagsResult).
				toResult();
		return result;
	} finally {
		driver.close();
	}
}

module.exports = searchArticles;
