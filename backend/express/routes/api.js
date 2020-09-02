'use strict';

const
	searchByTag = require('../../api/searchByTag.js'),
	getArticlesWithTag = require('../../api/getArticlesWithTag.js'),
	searchArticles = require('../../api/searchArticles.js'),
	getTagsForArticle = require('../../api/getTagsForArticle.js');


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
	router.get('/api/articles', api.searchArticles);
	router.get('/api/articles/:articleId/tags', api.getTagsForArticle);

	return router;
};
