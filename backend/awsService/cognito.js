'use strict';

module.exports = (config, cognito) => {

	const nameValueArrayToObject = arr => {
		return arr.reduce((acc, x) => {
			const name =
				x.Name.
					split('_').
					map((s) =>
						s.slice(0, 1).toUpperCase() + s.slice(1).toLowerCase()
					).
					join('');
			acc[name] = x.Value;
			return acc;
		}, {});
	};

	const getUser = async (accessToken) => {
		const params = {
			AccessToken: accessToken
		};
		const result = await cognito.getUser(params).promise();
		console.log(result);
		const cognitoUser = nameValueArrayToObject(result.UserAttributes);

		/* Example cognitoUSer
		{
			"Sub": "691a0d91-9432-402d-bd44-ac0364f99e8c",
			"PhoneNumberVerified": "true",
			"PhoneNumber": "+467012345678",
			"GivenName": "Foo",
			"FamilyName": "Barsson",
			"Email": "foo.bar@gmail.com"
		}
		*/

		return cognitoUser;
	};

	const getAdminUser = async (sub) => {
		const params = {
			UserPoolId: config.aws.cognito.userPoolId,
			Username: sub
		};

		const result = await cognito.adminGetUser(params).promise();
		return { ...result, UserAttributes: nameValueArrayToObject(result.UserAttributes) };
	};

	return {
		getUser,
		getAdminUser
	};
};
