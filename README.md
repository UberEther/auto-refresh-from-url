[![Build Status](https://travis-ci.org/UberEther/auto-refresh-from-url.svg?branch=master)](https://travis-ci.org/UberEther/auto-refresh-from-url)
[![NPM Status](https://badge.fury.io/js/auto-refresh-from-url.svg)](http://badge.fury.io/js/auto-refresh-from-url)

# Overview

This library provides a class for building objects that load their data from a URL and periodically refresh the data.

Methods are based on [Bluebird](https://github.com/petkaantonov/bluebird) promises.  HTTP requests are handled by [request](https://github.com/request/request).

The expected pattern is you will create a subclass of the class returned by this library.  This subclass will then override the methods prepareRefreshRequest() and processUrlData() as necessary.  For a good example on subclassing in Node, see the documentation on [subclassing the event emitter](https://nodejs.org/api/events.html#events_inheriting_from_eventemitter)

When using your new class, you should call refreshIfNeededAsync() to obtain a promise for the required data.
- Refreshes ONLY happen on a call to refreshIfNeededAsync() or refreshNowAsync().  They are not timed to occur automatically.
- On the initial request, the URL specified is loaded, processed, and the promise is not resolved until this is complete.
- On subsequent requests, the cached copy is normally returned
- Once the refreshDuration is hit, the promise is resolved with the cached copy immediately, but the data is updated and processed in background
- Once the expirationDuration is hit, the data is updated and processed prior to resolving the promise
- IF multiple refreshes occur in less than the doNotRefreshDuration, then the refresh request is ignored

You can also use refreshNowAsync() to force an immediate reload of the URL.  This function will honor doNotRefreshDuration UNLESS a parameter of true is passed in (to force the refresh).

Refresh promises are tracked so that only one refresh may be outstanding at any time.

# APIs:

## AutoRefresh(options)

Constructor for the auto-refresher.  Takes an options hash.  The following options are recognized:
- url: Optional - The url to load from
- request: Optional - The [request](https://github.com/request/request) object to use for this object.  If not specified, then the library will use its own internal copy.  If specified, it will be promisifed by the library (if necessary).
- requestDefaults - Optional - if using the internal version of Request, then these parameters are used by default for the requests.  Makes use of [request.defaults](https://github.com/request/request#requestdefaultsoptions).  Default is { method: "GET", json: true }.
- refreshDuration: Optional - The time after loading a resource before it will be background refreshed after.  May be specified in milliseconds OR in a string recognized by the [ms library](https://github.com/rauchg/ms.js).  Default is 1 day.
- expireDuration: Optional - The time after loading a resource before it will be forground refreshed after.  May be specified in milliseconds OR in a string recognized by the [ms library](https://github.com/rauchg/ms.js).  Default is 7 days.
- doNotRefreshDuration: Optional - Minimum time between resource refreshes (unless force is specified).  May be specified in milliseconds OR in a string recognized by the [ms library](https://github.com/rauchg/ms.js).  Default is 5 minutes.

## refreshIfNeededAsync()
Returns a promise that is resolved with the loaded data.
- If the data is expired, it is not resolved until the data is refreshed.

## refreshNowAsync(force)
Returns a promise that is resolved with the loaded data.
- If an existing refresh is in progress, that promise is returned
- If force is falsey and we have not been more than doNotRefreshBefore since the last refresh, the existing cached data is returned.

If refreshing from a URL, the actions are as followed:
- prepareRefreshRequest() is called to generate the request options.  Options may be changed by either specifying the requestDefaults option in the constructor or overriding this method.
- If the requestOptions includes a URL, then request.requestAsync is called with the specified options
- doNotRefreshBefore is updated
- If a 304 is received, the existing cached playload is returned
- processDataUrl() is called to process the payload
- All the state related to the payload is updated (refreshAt, expireAt, etag, lastModified)
- The promise is resolved with the new payload

## prepareRefreshRequest(oldPayload)
Function that returns the request options to obtain the necessary data.  It may also return a promise that resolves to the same.

Default builds options that include the URL and conditional values for If-None-Match (if we have an etag) or If-Modified-Since (if we have a lastModified).

In general, you should not need to override this method.  Instead, specify requestDefaults in the constructor options.

If you wish to generate the new payload yourself, return null.

## processUrlData(res, raw, oldPayload)
Function that processes the raw response from the URL request and converts it into the object returned by refreshIfNeededAsync() and refreshNowAsync().  It may also return a promise that resolves to the same.
- res is the HTTP response object from request.  May be null if we the requestOptions was null.
- raw is the raw response from the request.  Depending on the request options, this may be a buffer, string, or object.  If you specify ```json:true``` in the request options, then it will be parsed as JSON.  May be null if we the requestOptions was null.
- oldPayload is the prior loaded payload

The default implementation ensures the HTTP status code is 200 and then returns the raw result.

In most cases, it is expected that you would override this method.

# Events:

## backgrounUrlRefreshError, err
Emitted if an error occurs during refresh to allow processing of the error.

If no listeners are registered, the error callstack is logged to console.warn.

# Other

- AutoRefresh.request exposes the promisified version of request used by the library.

# EXAMPLES:

## Javascript
```js
var util = require('util');
var AutoRefresh = require('auto-refresh-from-url');

function GoogleHomepageCache() {
	AutoRefresh.call(this, {
		url: "http://google.com"
	});
}
util.inherits(CachedUrl, GoogleHomepageCache);

GoogleHomepageCache.processUrlData = function(res, raw) {
	if (res.statusCode != 200) throw new Error("Unexpected status code: "+res.statusCode);
	var rv = { raw: raw };
	// TODO: Add more processing here...
	return rv;
}

googleHomepageCache = new GoogleHomepageCache();

googleHomepageCache.refreshIfNeededAsync()
.then(function(rv) {
	console.log("%j", rv);
})
.catch(function(err) {
	console.error("Refresh failed: "+(err.stack || err.message || err));
});
```

## Coffeescript
```coffeescript
util = require 'util'
AutoRefresh = require 'auto-refresh-from-url'

class GoogleHomepageCache extends AutoRefresh
	constructor: () ->
		super url: "http://google.com"

	processUrlData: (res, raw) ->
		if res.statusCode != 200 then throw new Error "Unexpected status code: #{res.statusCode}"
		rv = raw: raw
		# TODO: Add more processing here...
		return rv

googleHomepageCache = new GoogleHomepageCache

googleHomepageCache.refreshIfNeededAsync()
.then (rv) -> console.log "%j", rv
.catch (err) -> console.error "Refresh failed: #{err.stack || err.message || err}"
```

# Contributing

Any PRs are welcome but please stick to following the general style of the code and stick to [CoffeeScript](http://coffeescript.org/).  I know the opinions on CoffeeScript are...highly varied...I will not go into this debate here - this project is currently written in CoffeeScript and I ask you maintain that for any PRs.