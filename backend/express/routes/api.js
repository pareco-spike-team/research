'use strict';

const
	searchByTag = require('../../api/searchByTag.js'),
	getArticlesWithTag = require('../../api/getArticlesWithTag.js'),
	searchArticles = require('../../api/searchArticles.js'),
	getTagsForArticle = require('../../api/getTagsForArticle.js'),
	editTagsForArticle = require('../../api/editTagsForArticle.js'),
	setColorOnLink = require('../../api/setColorOnLink.js'),
	removeColorOnLink = require('../../api/removeColorOnLink.js'),
	createTag = require('../../api/createTag.js');


const onError = (res) => err => {
	console.error(err);
	res.status(500).send();
};

const do_ = async (res, f) => {
	try {
		const result = await f();
		res.status(200).json(result);
	} catch (err) {
		onError(res)(err);
	}
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

const setColor = async (req, res) => {
	const username = req.session.user.username;
	const color = req.body.color.map(x => Math.round(255 * x));
	const from = req.body.from;
	const to = req.body.to;

	await do_(res, () => setColorOnLink(username, from, to, color))
};

const removeColor = async (req, res) => {
	const username = req.session.user.username;
	const from = req.body.from;
	const to = req.body.to;

	await do_(res, () => removeColorOnLink(username, from, to));
};

const editTagsForArticle_ = async (req, res) => {

	await do_(res, async () => {
		const articleId = req.params.articleId, actions = req.body.actions;
		return await editTagsForArticle(articleId, actions);
	});
};

const createTag_ = async (req, res) => {
	await do_(res, async () => {
		const newTag = req.body.newTag;
		const articleId = req.body.articleId;
		const addToAllArticlesMatchingTag = req.body.addToAllArticlesMatchingTag;

		return await createTag(newTag, articleId, addToAllArticlesMatchingTag);
	});
};

const api = {
	searchByTag: (req, res) => do_(res, () => searchByTag(req.query.filter)),
	getArticlesWithTag: (req, res) => do_(res, () => getArticlesWithTag(req.params.tagId)),

	searchArticles: (req, res) => do_(res, () => searchArticles(req.query.tagFilter, req.query.articleFilter)),
	getTagsForArticle: (req, res) => do_(res, () => getTagsForArticle(req.params.articleId, req.query.includeArticles)),
	editTagsForArticle: editTagsForArticle_,
	createTag: createTag_,

	getUser: getUser,
	setColor: setColor,
	removeColor: removeColor,
};

module.exports = () => {
	const
		express = require('express'),
		router = express.Router();

	router.get('/api/tags', api.searchByTag);
	router.post('/api/tags', api.createTag);
	router.get('/api/tags/:tagId/articles', api.getArticlesWithTag);
	router.get('/api/articles', api.searchArticles);
	router.get('/api/articles/:articleId/tags', api.getTagsForArticle);
	router.post('/api/articles/:articleId/tags', api.editTagsForArticle);
	router.post('/api/articles/:articleId/color', api.setColor);
	router.delete('/api/articles/:articleId/color', api.removeColor);

	router.get('/api/user', api.getUser);

	return router;
};
