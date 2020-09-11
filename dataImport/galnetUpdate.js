'use strict';

const
	{ getDriver, runQuery } = require('../backend/util/neoHelper'),
	request = require('request-promise-native'),
	shortId = require('shortid'),
	Case = require('case'),
	moment = require('moment');

const uri = "https://elitedangerous-website-backend-production.elitedangerous.com/api/galnet?_format=json";

async function getAllTags() {
	const driver = getDriver();
	let session = driver.session();
	const query = runQuery(session);
	const findAllTagsQuery = `MATCH (t:Tag) RETURN t.tag as tag ORDER BY tag`;
	const result = (await query(findAllTagsQuery)({}));
	driver.close();

	return result.map(x => x._fields[0]);
}

async function getNewestArticleDate() {
	const driver = getDriver();
	let session = driver.session();
	const query = runQuery(session);
	const findLargestArticleDate = `MATCH (a:Article) RETURN MAX(a.date) as date`;
	const result = (await query(findLargestArticleDate)({}));
	driver.close();

	const res = result[0] != null ? result[0]._fields[0] : null;
	return res || "2010-01-01";
}

async function saveArticles(articles) {
	console.log(`Saving ${articles.length} articles.`);
	const driver = getDriver();

	let session = driver.session();
	for (var article of articles) {
		let query = `
			MERGE (a:Article { title: {title}, date: {date} })
			ON CREATE SET a.id = {id}, a.text = {text}
			WITH a`;
		let args = {
			id: article.id,
			title: article.title.trim(),
			text: article.text.trim(),
			date: article.date
		};
		article.tags.forEach((tag, i) => {
			const tagQuery = `
				MATCH (t:Tag) WHERE t.tag = {tag${i}}
				MERGE (a)-[:Tag]->(t)
				WITH a
			`;
			query += tagQuery;
			args[`tag${i}`] = tag;
		});
		query += `
			RETURN 0`;
		try {
			console.log(`${article.date} ${article.title} (${article.id})`);
			await session.run(query, args);
		} catch (err) {
			console.error(err);
		}
	}

	driver.close();
}

async function readFeed() {
	const [newestArticleDateStr, tags] = await Promise.all([
		getNewestArticleDate(), getAllTags()
	]);
	const newestArticleDate =
		moment(newestArticleDateStr, "YYYY-MM-DD").
			subtract(2, "days").
			format("YYYY-MM-DD");
	const allTagsCapital = tags.map(x => Case.capital(x));

	const tagRegexes = tags.map(x => {
		return { tag: x, regex: new RegExp(`[^a-z]${x.toLowerCase()}[^a-z]`, "muisg") };
	});
	const hasSmallCharacters = /[a-z]/;
	const query = { uri: uri };
	const items = JSON.parse(await request(query));
	const articles =
		items.
			filter(x => x.slug !== "adder-ship-kit").
			map(x => {
				const title = (() => {
					if (!hasSmallCharacters.test(x.title)) {
						const t = Case.sentence(x.title, allTagsCapital, []);
						return t.trim();
					}
					return x.title.trim();
				})();
				return {
					id: `${x.nid}_${shortId.generate()}`,
					title: title,
					text: x.body.replace(/<p>/, '').replace(/<br \/>/g, '\n').replace(/<\/p>/, '').trim(),
					date: moment(x.date, "DD MMM YYYY").format("YYYY-MM-DD"),
					tags: []
				};
			}).
			filter(x => x.date >= newestArticleDate).
			map(x => {
				x.tags = tagRegexes.filter(t => t.regex.test(x.text)).map(t => t.tag);
				return x;
			});

	console.log(`${articles.length} articles to save.`);
	await saveArticles(articles);
}


readFeed().
	then(() => setTimeout(process.exit, 0)).
	catch(err => {
		console.error(err);
		setTimeout(process.exit, 1);
	});
