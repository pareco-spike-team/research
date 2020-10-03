'use strict';

const
	{ getDriver } = require('../backend/util/neoHelper.js'),
	markdownFileToParse = `${__dirname}/../data/Galnet_Revamp_no_HTML.txt`,
	Case = require('case'),
	markdownParse = require('./markdownParser.js');

const fixTagCasing = t =>
	t.tag.
		split(' ').
		map(x => x.slice(0, 1).toUpperCase() + x.slice(1)).
		join(' ');

const caseInsensitiveRegexMatch = x => `(?muis)${x.toLowerCase()}`;

const generateNextTagId = (() => {
	let count = 1;

	return () => {
		const s = `${count++}`.padStart(4, '0');
		return `tag_${s}`;
	};
})();


const generateNextArticleId = (() => {
	let count = 1;

	return () => {
		const s = `${count++}`.padStart(4, '0');
		return `article_${s}`;
	};
})();

async function saveTags(articles) {
	const tags = new Set();
	articles.forEach(a => {
		a.tags.forEach(t => {
			const tag_ = fixTagCasing(t);
			tags.add(tag_);
			t.subTags.forEach(s => tags.add(fixTagCasing(s)));
		});
	});
	const driver = getDriver();
	let session = driver.session();
	for (const t of [...tags.values()].sort()) {
		let query = `
			MERGE (t:Tag { tag: {tag} }) ON CREATE SET t.id = {id} RETURN t
		`;
		let args = {
			tag: t,
			id: generateNextTagId()
		};
		try {
			await session.run(query, args);
		} catch (err) {
			console.error(err);
		}
	}

	for (const a of articles) {
		for (const t of a.tags) {
			for (const s of t.subTags) {
				let query = `
					MATCH (t1:Tag) WHERE t1.tag =~ {t1}
					MATCH (t2:Tag) WHERE t2.tag =~ {t2}
					MERGE (t1)-[:Tag]->(t2)
					RETURN 0`;
				let args = {
					t1: caseInsensitiveRegexMatch(t.tag),
					t2: caseInsensitiveRegexMatch(s.tag)
				};
				try {
					await session.run(query, args);
				} catch (err) {
					console.error(err);
				}
			}
		}
	}
	driver.close();
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
			id: generateNextArticleId(),
			title: article.title.trim(),
			text: article.text.trim(),
			date: article.date
		};
		article.tags.forEach((tag, i) => {
			const tagQuery = `
				MATCH (t:Tag) WHERE t.tag =~ {tag${i}}
				MERGE (a)-[:Tag]->(t)
				WITH a
			`;
			query += tagQuery;
			args[`tag${i}`] = caseInsensitiveRegexMatch(tag.tag);
			tag.subTags.forEach((s, j) => {
				const subtagQuery = `
					MATCH (t:Tag) WHERE t.tag =~ {tag${i}_${j}}
					MERGE (a)-[:Tag]->(t)
					WITH a
				`;
				query += subtagQuery;
				args[`tag${i}_${j}`] = caseInsensitiveRegexMatch(s.tag);
			});
		});
		query += `
			RETURN 0`;
		try {
			await session.run(query, args);
		} catch (err) {
			console.error(err);
		}
	}

	driver.close();
}

function cleanTags(articles) {
	const cleanTagList = xs => {
		const cleaned = xs.
			map(x => ({ ...x, tag: x.tag.split(/\s+|\.|\?[,'"´`]/).join(' ').trim() })).
			filter(x => x.tag.length > 1);
		return [...new Set(cleaned)];
	};

	articles.forEach(a => {
		a.tags = cleanTagList(a.tags);
		a.tags.forEach(t => {
			t.subTags = cleanTagList(t.subTags);
		});
	});
}

function fixTitles(articles) {
	const r = /[a-z]/;
	const allTags =
		[...(articles.reduce((acc, a) => {
			a.tags.forEach(x => acc.add(Case.capital(x.tag)));
			return acc;
		}, new Set())).values()];

	articles.forEach(a => {
		if (!r.test(a.title)) {
			const t = Case.sentence(a.title, allTags, []);
			a.title = t;
		}
	});
}

async function addIndexes() {

	const indexes = [
		'CALL db.index.fulltext.createNodeIndex("TextTitleIndex", ["Article"],["text", "title"])',
		'CALL db.index.fulltext.createNodeIndex("TagIndex", ["Tag"],["tag"])',
		'CREATE CONSTRAINT ON (a:Article) ASSERT a.id IS UNIQUE',
		'CREATE CONSTRAINT ON (t:Tag) ASSERT t.id IS UNIQUE'
	];
	const driver = getDriver();
	let session = driver.session();
	for (const q of indexes) {
		await session.run(q, {});
	}
	driver.close();
}

const p = new Promise((resolve, reject) => {
	const articles = markdownParse(markdownFileToParse);
	cleanTags(articles);
	fixTitles(articles);

	return saveTags(articles).
		then(() => saveArticles(articles)).
		then(() => addIndexes()).
		then(resolve).
		catch(reject);
});

p.
	then(() => setTimeout(process.exit, 0)).
	catch(err => {
		console.error(err);
		setTimeout(process.exit, 1);
	});

