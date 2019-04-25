'use strict';

const
	{ getDriver, runQuery } = require('./neoHelper'),
	englishWords = new Set(require('an-array-of-english-words'));

async function doIt() {
	const driver = getDriver();
	const session = driver.session();

	const tags = new Set((await runQuery(session)("MATCH (t:Tag) RETURN t.tag as tag")({})).map(x => x.tag.toLowerCase()));
	const articles = await runQuery(session)("MATCH (a:Article) RETURN a.title as title, a.text as text, a.date as date ORDER BY a.title")({});
	// .map(x => x.article);
	const allNonEnglishWords = new Set();
	articles.forEach(a => {
		const words =
			a.text.split(/\s+|\-|[._:;,.!?"‘’“”()]|\'/).
				filter(x => /^\s+$/.test(x) === false).
				filter(x => /^\d+$/.test(x) === false).
				map(x => ({ untouched: x, lowercase: x.trim().toLowerCase() })).
				filter(x => x.lowercase.trim().length > 1);

		const notEnglish =
			words.
				filter(w => !(englishWords.has(w.lowercase))).
				filter(w => !tags.has(w.lowercase));
		notEnglish.forEach(x => allNonEnglishWords.add(x.untouched));
		// const notEnglishUnique = [...new Set(notEnglish.map(x => x.untouched))];

		const regex = [
			"([A-Z]+\\w*\\s?){2,5}",
			"(\\d+\\s?)[A-Z]+\\w* (\\d+\\s?)?[A-Z]\\w*",
			"[A-Z]+\\w* (\\d+\\s?)?[A-Z]+\\w*",
			"[A-Z]+\\w* \\d+"
		].map(x => `(${x})`).join('|');
		const matches = a.text.match(new RegExp(regex, "g")) || [];
		const capLetters = [...new Set(matches.map(x => x.trim()))];
		console.log(`'${a.title}' :: `, capLetters.join(', '));
	});
	// const nonEng = [...allNonEnglishWords.values()];
	// console.log(`all ::\n`, nonEng.join(',\n'));
}

doIt().
	then(() => setTimeout(process.exit, 10, 0)).
	catch(err => {
		console.error(err);
		setTimeout(process.exit, 10, 1);
	});
