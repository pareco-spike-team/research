'use strict';

const
	searchByTag = require('../../api/searchByTag.js'),
	getArticlesWithTag = require('../../api/getArticlesWithTag.js'),
	searchArticles = require('../../api/searchArticles.js'),
	getTagsForArticle = require('../../api/getTagsForArticle.js'),
	setColorOnLink = require('../../api/setColorOnLink.js'),
	removeColorOnLink = require('../../api/removeColorOnLink.js'),
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

const setColor = async (req, res) => {
	const username = req.session.user.username;
	const color = req.body.color.map(x => Math.round(255 * x));
	const from = req.body.from;
	const to = req.body.to;

	try {
		const result = await setColorOnLink(username, from, to, color);
		res.json(result);
	} catch (err) {
		onError(res)(err);
	}
};

const removeColor = async (req, res) => {
	const username = req.session.user.username;
	const from = req.body.from;
	const to = req.body.to;

	try {
		const result = await removeColorOnLink(username, from, to);
		res.json(result);
	} catch (err) {
		onError(res)(err);
	}
};

const createTag_ = async (req, res) => {
	try {
		const newTag = req.body.newTag;
		const articleId = req.body.articleId;
		const addToAllArticlesMatchingTag = req.body.addToAllArticlesMatchingTag;
		const result = await createTag(newTag, articleId, addToAllArticlesMatchingTag);
		res.json(result);
	} catch (err) {
		onError(res)(err);
	}
};

const api = {
	searchByTag: (req, res) => get(res, () => searchByTag(req.query.filter)),
	getArticlesWithTag: (req, res) => get(res, () => getArticlesWithTag(req.params.tagId)),

	searchArticles: (req, res) => get(res, () => searchArticles(req.query.tagFilter, req.query.articleFilter)),
	getTagsForArticle: (req, res) => get(res, () => getTagsForArticle(req.params.articleId, req.query.includeArticles)),
	createTag: (req, res) => createTag_(req, res),

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
	router.post('/api/articles/:articleId/color', api.setColor);
	router.delete('/api/articles/:articleId/color', api.removeColor);

	router.get('/api/user', api.getUser);

	return router;
};
