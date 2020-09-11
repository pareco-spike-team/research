'use strict';

const
	{ getDriver, runQuery } = require('../../util/neoHelper'),
	shortId = require('shortid'),
	Case = require('case'),
	moment = require('moment');

const getAllTags = driver => runQuery_ => async () => {
	const session = driver.session();
	const query = runQuery_(session);
	const findAllTagsQuery = `MATCH (t:Tag) RETURN t.tag as tag ORDER BY tag`;
	const result = (await query(findAllTagsQuery)({}));
	driver.close();

	return result.map(x => x._fields[0]);
};

const getNewestArticleDate = driver => runQuery_ => async () => {
	const session = driver.session();
	const query = runQuery_(session);
	const findLargestArticleDate = `MATCH (a:Article) RETURN MAX(a.date) as date`;
	const result = await query(findLargestArticleDate)({});
	driver.close();

	return result[0] != null ? result[0]._fields[0] : null;
};

const saveArticles = driver => async (articles) => {
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
			console.error('Failed to save article', JSON.stringify({ err: err, article: article }));
		}
	}

	driver.close();
};

const run = async (items) => {
	const [newestArticleDateStr, tags] = await Promise.all([
		getNewestArticleDate(getDriver())(runQuery)(),
		getAllTags(getDriver())(runQuery)()
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

	const articles =
		items.
			filter(x => x.slug !== "adder-ship-kit").
			map(x => {
				try {
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
				} catch (err) {
					console.error('Failed to map article', JSON.stringify({ err: err, article: x }));
					throw err;
				}
			}).
			filter(x => x.date >= newestArticleDate).
			map(x => {
				x.tags = tagRegexes.filter(t => t.regex.test(x.text)).map(t => t.tag);
				return x;
			});

	console.log(`${articles.length} articles to save.`);
	await saveArticles(getDriver())(articles);
};

async function lambdaRun(event) {
	try {
		const items =
			event.Records.
				map(x => JSON.parse(x.body)).
				reduce((acc, x) => [...acc, ...x], []);

		await run(items);
		return { message: 'function execution success!', event };
	} catch (err) {
		console.error('GalnetArticleSave failed to handle event', { event: event, err: err });
		return { message: 'function execution failed!', event: event, err: err.stack || err };
	}
}

exports.run = lambdaRun;

/*
async function localRun() {
	try {
		const
			{ readdirSync, readFileSync, unlinkSync: deleteFile } = require('fs'),
			join = require('path').join,
			dir = join(__dirname, '..', '..', '..', '.queue_msgs', 'galnet-article');

		const files = readdirSync(dir);
		const file = files.length > 0 ? join(dir, files[0]) : null;
		const items = file != null ?
			JSON.parse(readFileSync(file).toString()) :
			[];

		await run(items);
		if (file != null) {
			deleteFile(file);
		}
	} catch (err) {
		console.error(err);
	}
}

localRun().
	then(() => process.exit(0)).
	catch(err => {
		console.error(err);
		process.exit(1);
	});
*/
