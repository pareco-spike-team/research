'use strict';

const
	searchByTag = require('../../api/searchByTag.js'),
	getArticlesWithTag = require('../../api/getArticlesWithTag.js'),
	searchArticles = require('../../api/searchArticles.js'),
	getTagsForArticle = require('../../api/getTagsForArticle.js');
	createTag = require('../../api/createTag.js');


const onError = (res) => err => {
	console.error(err);
	res.status(500).send();
};

const get = (res, f) => {
	f().
		then(result => res.status(200).json(result)).
		catch(onError(res));
};

const isSessionExpired = req => {
	const cognitoSession = req.session.cognito;
	if (!cognitoSession) {
		return true;
	}
	const expired = new Date() > new Date(cognitoSession.expiresAt);
	return expired;
};

const getUser = async (req, res) => {
	try {
		if (isSessionExpired(req)) {
			res.status(401).send('Not logged in');
		} else {
			res.json(req.session.user);
		}
	}
	catch (err) {
		onError(res)(err);
	}
};

const api = {
	searchByTag: (req, res) => get(res, () => searchByTag(req.query.filter)),
	getArticlesWithTag: (req, res) => get(res, () => getArticlesWithTag(req.params.tagId)),

	searchArticles: (req, res) => get(res, () => searchArticles(req.query.tagFilter, req.query.articleFilter)),
	getTagsForArticle: (req, res) => get(res, () => getTagsForArticle(req.params.articleId, req.query.includeArticles)),

	createTag: (req, res) => get(res, () => createTag(req.params.tagName)),

	getUser: getUser
};

module.exports = () => {
	const
		express = require('express'),
		router = express.Router();

	router.get('/api/tags', api.searchByTag);
	router.get('/api/tags/:tagId/articles', api.getArticlesWithTag);
	router.get('/api/articles', api.searchArticles);
	router.get('/api/articles/:articleId/tags', api.getTagsForArticle);
	router.get('/api/tags/create', api.createTag);

	router.get('/api/user', api.getUser);

	return router;
};
