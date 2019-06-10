'use strict';

const
	{ getDriver, runQuery } = require('../../util/neoHelper.js');

async function searchByTag(filter) {
	const driver = getDriver();
	const s = driver.session();
	const tagMatch = filter ? `(?muis)${filter}` : null;
	const query = filter ?
		"MATCH (tag:Tag) WHERE tag.tag =~ {tag} RETURN tag ORDER BY tag.tag" :
		"MATCH (tag:Tag) RETURN tag ORDER BY tag.tag";
	const result = await runQuery(s)(query)({ tag: tagMatch });
	driver.close();
	return result;
}

function mapToReturn(mapAcc, xs) {
	const result =
		xs.reduce((res, x) => {
			const match = res.get(x.article.id);
			if (match == null) {
				x.tags = [x.tag];
				delete x.tag;
				res.set(x.article.id, x);
			} else {
				match.tags = [...match.tags, x.tag];
			}
			return res;
		}, mapAcc);

	return result;
}

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

async function getTagsForArticle(articleId, includeArticles) {
	const driver = getDriver();
	try {
		const s = driver.session();
		const query =
			`MATCH (article:Article)-[:Tag]->(tag:Tag) WHERE article.id = {articleId} WITH tag
		MATCH (tag)<-[:Tag]-(article:Article) WHERE article.id = {articleId} OR article.id IN {includeArticles} RETURN tag, article`;
		const toInclude = includeArticles ? includeArticles.split(',').map(x => x.trim()) : [];

		const result = await runQuery(s)(query)({ articleId: articleId, includeArticles: toInclude });
		const mapResult = mapToReturn(new Map(), result);
		return [...mapResult.values()];
	} finally {
		driver.close();
	}
}

async function getArticlesWithTag(tagId) {
	const driver = getDriver();
	const s = driver.session();
	const query =
		"MATCH (article:Article)-[:Tag]->(tag:Tag) WHERE tag.id = {tagId} RETURN article, tag";
	const result = await runQuery(s)(query)({ tagId: tagId });
	driver.close();
	return result;
}

const onError = (res) => err => {
	console.error(err);
	res.status(500).send();
};

const get = (res, f) => {
	f().
		then(result => res.status(200).json(result)).
		catch(onError(res));
};

const api = {
	searchByTag: (req, res) => get(res, () => searchByTag(req.query.filter)),
	getArticlesWithTag: (req, res) => get(res, () => getArticlesWithTag(req.params.tagId)),

	searchArticles: (req, res) => get(res, () => searchArticles(req.query.tagFilter, req.query.articleFilter)),
	getTagsForArticle: (req, res) => get(res, () => getTagsForArticle(req.params.articleId, req.query.includeArticles))
};

module.exports = () => {
	const
		express = require('express'),
		router = express.Router();

	router.get('/api/tags', api.searchByTag);
	router.get('/api/tags/:tagId/articles', api.getArticlesWithTag);
	// router.put('/api/tags', api.updateTag);
	// router.post('/api/tags', api.createTag);

	router.get('/api/articles', api.searchArticles);
	router.get('/api/articles/:articleId/tags', api.getTagsForArticle);

	return router;
};
