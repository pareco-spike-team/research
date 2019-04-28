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

async function searchArticles(tags, filter) {
	const driver = getDriver();
	const s = driver.session();
	const tagMatch = tags ?
		'(?muis)' + (tags.split(',').map(x => x.trim()).map(x => `${(x.toLowerCase())}`).join('|')) :
		null;
	const articleMatch = filter ? `(?muis)${filter}` : null;

	let query = [
		"MATCH (article:Article)-[:Tag]->(tag:Tag)",
		(tagMatch || articleMatch) ? "WHERE" : null,
		(tagMatch) ? "tag.tag =~ {tag}" : null,
		(tagMatch && articleMatch) ? "AND" : null,
		(articleMatch) ? "(article.title =~ {article} OR article.text =~ {article})" : null,
		"RETURN article, tag"
	].
		filter(x => x != null).
		join(' ');
	const args = {
		tag: tagMatch,
		article: articleMatch
	};

	const result = await runQuery(s)(query)(args);
	driver.close();
	return result;
}

async function getTagsForArticle(articleId) {
	const driver = getDriver();
	const s = driver.session();
	const query =
		"MATCH (article:Article)-[:Tag]->(tag:Tag) WHERE article.id = {articleId} RETURN article, tag";
	const result = await runQuery(s)(query)({ articleId: articleId });
	driver.close();
	return result;
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
	getTagsForArticle: (req, res) => get(res, () => getTagsForArticle(req.params.articleId))
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
