// Only require coffeescript if it is not already registered
/* istanbul ignore if  */
if (!require.extensions[".coffee"]) require("coffee-script/register");

module.exports = {
	CachedLoader: require("./cachedLoader.coffee"),
	FileLoader: require("./fileLoader.coffee"),
	StaticLoader: require("./staticLoader.coffee"),
	UrlLoader: require("./urlLoader.coffee")
};