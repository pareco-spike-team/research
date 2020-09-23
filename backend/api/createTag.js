'use strict';

const
	{ getDriver, runQuery } = require('../util/neoHelper.js');

const caseInsensitiveRegexMatch = x => `(?muis)${x.toLowerCase()}`;

async function createTag(name) {
    const driver = getDriver();
    let s = driver.session();
    const tagName = name ? `(?muis)${name}` : null;
    if (!tagName) return false;

    let addTag = `
        MERGE (t:Tag { tag: {tag} }) ON CREATE SET t.id = {id} RETURN t
    `;
    let args = {
        tag: tagName,
        id: shortId.generate()
    };
    try {
        const result = await runQuery(s)(addTag)(args);
		console.log(`${result[0].tag} new tag created '${tagName}'`);
        const tagArticles = `
            MATCH (a:Article)
            WHERE (a.text =~ {tagMatch} OR a.title =~ {tagMatch})
                AND lower(a.title) <> 'week in review'
                AND (NOT lower(a.title) STARTS WITH 'community goal:')
                AND (NOT lower(a.title) STARTS WITH 'freelance report:')
                AND (NOT lower(a.title) STARTS WITH 'a week in powerplay')
            MATCH (t:Tag) WHERE t.tag = {tag}
            MERGE (a)-[:Tag]->(t)
            RETURN count(a) AS articlesUpdated`;

        const result = await runQuery(s)(tagArticles)({tagMatch: caseInsensitiveRegexMatch(tagName)});
        
		console.log(`${result[0].articlesUpdated} articles received new tag '${tagName}'`);
    } catch (err) {
        console.error(err);
    }
	driver.close();
	return result;
}

module.exports = createTag;
