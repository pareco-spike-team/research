"use strict";

const
	config = require("../../config.js"),
	webApp = require("./app.js")(config);

const
	httpPort = 8088;

(function startupNotification() {
	console.log(`Server started with environment ${config.env}`);
})();

(function createHttpServer() {
	const app = webApp.start;
	app.listen(httpPort);
})();

const exitNotification = (message, from) => {
	console.log("Server Exit", [message, from]);
};

process.on("exit", (code) => {
	exitNotification(code, "exit");
});

process.on("SIGINT", () => {
	exitNotification("SIGINT");
	setTimeout(() => process.exit(0), 100);
});

process.on("uncaughtException", (error) => {
	console.log("FATAL. BYE: ");
	console.log(error);
	exitNotification(error, "uncaughtException");
	setTimeout(() => process.exit(0), 100);
});
