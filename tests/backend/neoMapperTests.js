'use strict';

const
	expect = require('chai').expect,
	mapper = require('../../backend/util/neoMapper.js');

describe('mapping data to return', () => {

	it('should map an article', async () => {
		const neoData = [
			{
				keys: ['article'],
				_fields: [
					{
						identity: { low: 1, high: 0 },
						labels: ['Article'],
						properties: {
							id: "a1",
							text: "text"
						}
					}
				],
				_fieldLookup: {
					article: 0
				}
			}
		];

		const mapped = mapper().map(neoData).toResult();
		const expected = [
			{ _meta: { type: "Label", label: "Article" }, id: "a1", text: "text" }
		];

		expect(mapped).to.eql(expected);
	});

	it('multiple articles of same articles are turned into one article', async () => {
		const neoData = [
			{
				keys: ['article'],
				_fields: [
					{
						identity: { low: 1, high: 0 },
						labels: ['Article'],
						properties: {
							id: "a1",
							text: "text"
						}
					}
				],
				_fieldLookup: {
					article: 0
				}
			},
			{
				keys: ['article'],
				_fields: [
					{
						identity: { low: 1, high: 0 },
						labels: ['Article'],
						properties: {
							id: "a1",
							text: "text"
						}
					}
				],
				_fieldLookup: {
					article: 0
				}
			}
		];

		const mapped = mapper().map(neoData).toResult();
		const expected = [
			{ _meta: { type: "Label", label: "Article" }, id: "a1", text: "text" }
		];

		expect(mapped).to.eql(expected);
	});

	it('should map an article with a tag', async () => {
		const neoData = [
			{
				keys: ['article', 'tag'],
				_fields: [
					{
						identity: { low: 1, high: 0 },
						labels: ['Article'],
						properties: {
							id: "a1",
							text: "text"
						}
					},
					{
						identity: { low: 3, high: 0 },
						labels: ["Tag"],
						properties: {
							tag: "the_tag",
							id: "t1"
						}
					}
				],
				_fieldLookup: {
					article: 0,
					tag: 1
				}
			}
		];

		const mapped = mapper().map(neoData).toResult();
		const expected = [
			{ _meta: { type: "Label", label: "Article" }, id: "a1", text: "text" },
			{ _meta: { type: "Label", label: "Tag" }, id: "t1", tag: "the_tag" }
		];

		expect(mapped).to.eql(expected);
	});

	it('multiple articles of same articles with different tags are turned into one article with 2 tags', async () => {
		const neoData = [
			{
				keys: ['article', 'tag'],
				_fields: [
					{
						identity: { low: 1, high: 0 },
						labels: ['Article'],
						properties: {
							id: "a1",
							text: "text"
						}
					},
					{
						identity: { low: 3, high: 0 },
						labels: ["Tag"],
						properties: {
							tag: "the_tag",
							id: "t1"
						}
					}
				],
				_fieldLookup: {
					article: 0,
					tag: 1
				}
			},
			{
				keys: ['article', 'tag'],
				_fields: [
					{
						identity: { low: 1, high: 0 },
						labels: ['Article'],
						properties: {
							id: "a1",
							text: "text"
						}
					},
					{
						identity: { low: 4, high: 0 },
						labels: ["Tag"],
						properties: {
							tag: "the_other_tag",
							id: "t2"
						}
					}
				],
				_fieldLookup: {
					article: 0,
					tag: 1
				}
			}
		];

		const mapped = mapper().map(neoData).toResult();
		const expected = [
			{ _meta: { type: "Label", label: "Article" }, id: "a1", text: "text" },
			{ _meta: { type: "Label", label: "Tag" }, id: "t1", tag: "the_tag" },
			{ _meta: { type: "Label", label: "Tag" }, id: "t2", tag: "the_other_tag" }
		];

		expect(mapped).to.eql(expected);
	});

	it('should map link between article and Tag', async () => {
		const neoData = [
			{
				keys: ['article', 'tag', 'tagAttributes'],
				_fields: [
					{
						identity: { low: 1, high: 0 },
						labels: ['Article'],
						properties: {
							id: "a1",
							text: "text"
						}
					},
					{
						identity: { low: 3, high: 0 },
						labels: ["Tag"],
						properties: {
							tag: "the_tag",
							id: "t1"
						}
					},
					{
						identity: { low: 5, high: 0 },
						start: { low: 1, high: 0 },
						end: { low: 3, high: 0 },
						type: "Tag",
						properties: {}
					}

				],
				_fieldLookup: {
					article: 0,
					tag: 1,
					tagAttributes: 2
				}
			}
		];

		const mapped = mapper().map(neoData).toResult();
		const expected = [
			{ _meta: { type: "Label", label: "Article" }, id: "a1", text: "text" },
			{ _meta: { type: "Label", label: "Tag" }, id: "t1", tag: "the_tag" },
			{ _meta: { type: "Tag", label: "Link", from: "a1", to: "t1" } }
		];

		expect(mapped).to.eql(expected);
	});

	it('should map multiple links between one article and multiple Tags', async () => {
		const neoData = [
			{
				keys: ['article', 'tag', 'tagAttributes'],
				_fields: [
					{
						identity: { low: 1, high: 0 },
						labels: ['Article'],
						properties: {
							id: "a1",
							text: "text"
						}
					},
					{
						identity: { low: 3, high: 0 },
						labels: ["Tag"],
						properties: {
							tag: "the_tag",
							id: "t1"
						}
					},
					{
						identity: { low: 5, high: 0 },
						start: { low: 1, high: 0 },
						end: { low: 3, high: 0 },
						type: "Tag",
						properties: {}
					}

				],
				_fieldLookup: {
					article: 0,
					tag: 1,
					tagAttributes: 2
				}
			},
			{
				keys: ['article', 'tag', 'tagAttributes'],
				_fields: [
					{
						identity: { low: 1, high: 0 },
						labels: ['Article'],
						properties: {
							id: "a1",
							text: "text"
						}
					},
					{
						identity: { low: 4, high: 0 },
						labels: ["Tag"],
						properties: {
							tag: "the_other_tag",
							id: "t2"
						}
					},
					{
						identity: { low: 6, high: 0 },
						start: { low: 1, high: 0 },
						end: { low: 4, high: 0 },
						type: "Tag",
						properties: {}
					}

				],
				_fieldLookup: {
					article: 0,
					tag: 1,
					tagAttributes: 2
				}
			}
		];

		const mapped = mapper().map(neoData).toResult();
		const expected = [
			{ _meta: { type: "Label", label: "Article" }, id: "a1", text: "text" },
			{ _meta: { type: "Label", label: "Tag" }, id: "t1", tag: "the_tag" },
			{ _meta: { type: "Tag", label: "Link", from: "a1", to: "t1" } },
			{ _meta: { type: "Label", label: "Tag" }, id: "t2", tag: "the_other_tag" },
			{ _meta: { type: "Tag", label: "Link", from: "a1", to: "t2" } }
		];

		expect(mapped).to.eql(expected);
	});

	it('should map properties on link', async () => {
		const neoData = [
			{
				keys: ['article', 'tag', 'tagAttributes'],
				_fields: [
					{
						identity: { low: 1, high: 0 },
						labels: ['Article'],
						properties: {
							id: "a1",
							text: "text"
						}
					},
					{
						identity: { low: 3, high: 0 },
						labels: ["Tag"],
						properties: {
							tag: "the_tag",
							id: "t1"
						}
					},
					{
						identity: { low: 5, high: 0 },
						start: { low: 1, high: 0 },
						end: { low: 3, high: 0 },
						type: "Tag",
						properties: {
							color_tinfoil: [
								{ low: 0, high: 0 },
								{ low: 1, high: 0 },
								{ low: 2, high: 0 }
							]

						}
					}

				],
				_fieldLookup: {
					article: 0,
					tag: 1,
					tagAttributes: 2
				}
			}
		];

		const mapped = mapper().map(neoData).toResult();
		const expected = [
			{ _meta: { type: "Label", label: "Article" }, id: "a1", text: "text" },
			{ _meta: { type: "Label", label: "Tag" }, id: "t1", tag: "the_tag" },
			{ _meta: { type: "Tag", label: "Link", from: "a1", to: "t1" }, color: [0, 1, 2] }
		];

		expect(mapped).to.eql(expected);
	});

	it('calling mapper twice will return articles, tags and links from both calls', async () => {
		const neoData1 = [
			{
				keys: ['article', 'tag', 'tagAttributes'],
				_fields: [
					{
						identity: { low: 1, high: 0 },
						labels: ['Article'],
						properties: {
							id: "a1",
							text: "text"
						}
					},
					{
						identity: { low: 3, high: 0 },
						labels: ["Tag"],
						properties: {
							tag: "the_tag",
							id: "t1"
						}
					},
					{
						identity: { low: 5, high: 0 },
						start: { low: 1, high: 0 },
						end: { low: 3, high: 0 },
						type: "Tag",
						properties: {}
					}
				],
				_fieldLookup: {
					article: 0,
					tag: 1,
					tagAttributes: 2
				}
			}
		];
		const neoData2 = [
			{
				keys: ['article', 'tag', 'tagAttributes'],
				_fields: [
					{
						identity: { low: 1, high: 0 },
						labels: ['Article'],
						properties: {
							id: "a1",
							text: "text"
						}
					},
					{
						identity: { low: 4, high: 0 },
						labels: ["Tag"],
						properties: {
							tag: "the_other_tag",
							id: "t2"
						}
					},
					{
						identity: { low: 6, high: 0 },
						start: { low: 1, high: 0 },
						end: { low: 4, high: 0 },
						type: "Tag",
						properties: {}
					}
				],
				_fieldLookup: {
					article: 0,
					tag: 1,
					tagAttributes: 2
				}
			}
		];

		const mapped =
			mapper().
				map(neoData1).
				map(neoData2).
				toResult();
		const expected = [
			{ _meta: { type: "Label", label: "Article" }, id: "a1", text: "text" },
			{ _meta: { type: "Label", label: "Tag" }, id: "t1", tag: "the_tag" },
			{ _meta: { type: "Tag", label: "Link", from: "a1", to: "t1" } },
			{ _meta: { type: "Label", label: "Tag" }, id: "t2", tag: "the_other_tag" },
			{ _meta: { type: "Tag", label: "Link", from: "a1", to: "t2" } }
		];

		expect(mapped).to.eql(expected);
	});

});
