'use strict';

const
	fs = require('fs');
/*
	How to interpret the markdown
	# - article title
	## - tag on article
	### subtag
	* Tag (star system)
	    * starport
*/

function parse(fileName) {
	const content = ("" + fs.readFileSync(fileName));
	const rows = content.split('\n');

	const parsedArticles =
		rows.reduce((articles, row) => {
			const trimmedRow = row.trim();
			const isSubTag = trimmedRow.startsWith('###');
			const isTag = !isSubTag && trimmedRow.startsWith('##');
			const isTitle = !isTag && trimmedRow.startsWith('#');
			const isStation = row.startsWith('    *');
			const isSystem = !isStation && /^\* \w+/.test(trimmedRow);
			if (isSubTag) {
				const tag = trimmedRow.slice(3).trim();
				const parent = articles.current.tags.slice(-1)[0];
				parent.subTags.push({ tag: tag });
			} else if (isTag) {
				articles.current.tags.push({ tag: trimmedRow.slice(2).trim(), subTags: [] });
			} else if (isSystem) {
				articles.current.tags.push({ tag: trimmedRow.slice(2).trim(), subTags: [], type: 'system' });
			} else if (isStation) {
				const parent = articles.current.tags.slice(-1)[0];
				parent.subTags.push({ tag: trimmedRow.slice(2).trim() });
			} else if (isTitle) {
				articles.current = {
					title: trimmedRow.slice(1).trim(),
					text: '',
					tags: []
				};
				articles.all.push(articles.current);
			} else {
				if (/^\d{4}-\d{2}-\d{2}$/.test(trimmedRow)) {
					articles.current.date = trimmedRow;
				} else {
					articles.current.text = `${articles.current.text}\n${trimmedRow}`;
				}
			}

			return articles;
		}, { current: null, all: [] });

	return parsedArticles.all;
}


module.exports = parse;
