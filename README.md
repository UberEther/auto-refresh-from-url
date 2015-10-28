[![Build Status](https://travis-ci.org/UberEther/auto-refresh-from-url.svg?branch=master)](https://travis-ci.org/UberEther/auto-refresh-from-url)
[![NPM Status](https://badge.fury.io/js/auto-refresh-from-url.svg)](http://badge.fury.io/js/auto-refresh-from-url)

# TODO:
- [ ] Rename project - it is now more general than the original name of ```auto-refresh-from-url```

# Overview

This library provides a class for building objects that load their data from a URL (or other sources) and periodically refresh the data.  For a complete example on using this library, see: [uberether-jwk](https://github.com/UberEther/jwk)

Methods are based on [Bluebird](https://github.com/petkaantonov/bluebird) promises.  If you require callbacks, you can use the [Bluebird nodeify method](https://github.com/petkaantonov/bluebird/blob/master/API.md#nodeifyfunction-callback--object-options---promise).  For example: ```foo.somethingTharReturnsPromise().nodeify(callback);```

HTTP requests are handled by [request](https://github.com/request/request).  You can control HTTP options via request or requestDefaults in the constructor options.

The library is based on loader classes which provide the following methods:
- A ```loadAsync(check)``` method which returns a bluebird promise that resolves to the processed data
    - If check is not truthy, then the class may return cached data
    - If check is truthy, then the class should check and update cached data
- A ```reset()``` method to force any cached data to be cleared


The following types of loaders are provided:
- ```StaticLoader``` which always returns the object passed into the constructor
- ```FileLoader``` which loads data from a file.  A processor method may be provided to transform the data.  The class will establish a file monitor to invalidate the cached data if the file is modified.
- ```UrlLoader``` which loads data from a URL.  A processor method may be provided to transform the data.  The class will track the etag and last-modified result headers and conditionally load updates when checking.
- ```CachedLoader``` which tracks when the objects were last checked for updates and will conditionally request checks automatically.  This class also prevents multiple concurrent load requests from being executed and rate limits the check requests.  This class does not directly load data - a loader of another type must be provided in the constructor.

In general, it is expected that most applications will instantiate a ```CachedLoader``` wrapping another loader.

# Example
```js
var Loaders = require("auto-refresh-from-url");

var urlLoader = new Loaders.UrlLoader("https://google.com");
var cachedLoader = new Loaders.CachedLoader(urlLoader);

cachedLoader.loadAsync().then(funciton(val) { console.log("%j", val.payload); });
```

# API Docs
## Class: StaticLoader
Class that "loads" static values

### new StaticLoader(value)
Instaniates a new StaticLoader that always returns ```value```

### StaticLoader.loadAsync(check)
Returns a promise which resolves to an object with 2 properties:
- payload: The value passed into the constructor
- loaded: Always false

### StaticLoader.reset()
No-op method for compatiblity with the loader signature

## FileLoader
Class that loads values from a file.  A file monitor may be established by default to monitor for changes.

### new FileLoader(fileName, options)
Constructs a new loader for the specified file.

Options allowed are:
- doNotMonitor: Do not establish a monitor for the file.  The file will be reloaded on initial request or if check is specified on loadAsync.
- processor: A function that takes the loaded value and returns the value to return from loadAsync OR a promise for said value
- default: A value to return if the file is missing.  This value is NOT passed to the processor.  If not set, then errors will be thrown if the file is not found.
- readOpts: The options to pass to readFile - defaults to ```{ encoding: "utf8", flag: "r" }```

### FileLoader.loadAsync(check)
Returns a promise which resolves to an object with 2 properties:
- payload: The value loaded and transformed by the processor option
- loaded: True if new data was loaded, false if cached values were used

New data is loaded if it was never loaded, has been reset, or if the file changed.

### FileLoader.reset()
Resets all cached data in the loader, forcing a reload of the file on the next loadAsync request.

Note that if a load is in-progress when reset() is called, the load already in progress will be retained.

## UrlLoader
Class that loads values using HTTP/HTTPS.  When checking for changes, etags and last-modified headers may be used.

## UrlLoader.request
The copy of request used by the URL loader (if not overridden in options)

### new UrlLoader(url, options)
Constructs a new loader for the specified url.

Options allowed are:
- request: A pre-configured copy of request for making loads from.  If not specified, UrlLoader.request will be used.
- requestDefaults: IF options.request was not specified, then these options will be used as defaults in the request call.  NOT USED if options.request is specified.  Default is ```{ json: true, method: "GET" }```
- ignoreEtag: If true, then etag headers are ignored and not used when checking for modified content
- ignoreLastModified: If true, then last-modified headers are ignored and not used when checking for modified content
- allowedResultCodes: Array of result codes considered to be a success.  Default is ```[200]```.
- processor: A function that takes the loaded value and returns the value to return from loadAsync OR a promise for said value

### UrlLoader.loadAsync(check)
Returns a promise which resolves to an object with 2 properties:
- payload: The value loaded and transformed by the processor option
- loaded: True if new data was loaded, false if cached values were used

The URL is checked if data has never been loaded, check is true, or if the loader was reset.

### UrlLoader.reset()
Resets all cached data in the loader, forcing a reload of the data on the next loadAsync request.

Note that if a load is in-progress when reset() is called, the load already in progress will be retained.


## CachedLoader
This is a wrapper loader to apply dynamic cache refreshing to a child loader.  It provides the following:
- Assurance that only one low-level load is outstanding at a time
- Minimum time between checks for updates
- Automatic background refresh after a certain time
- Expiration of cached data after a certain time

### new CachedLoader(childLoader, options)
Constructs a new cached loader that uses childLoader for low-level loading.
Options allowed are:
- doNotCheckDuration: Minimum duration allowed between checking for updates.  May be milliseconds or an ms library compatible string.  Default is: ```"5m"```.
- refreshDuration: Time period after which a load will trigger a background check of cached data.  May be milliseconds or an ms library compatible string.  Default is: ```"1d"```.
- expireDuration: Time period after which the cache will be cleared to force an update of the data.  May be milliseconds or an ms library compatible string.  Default is: ```"7d"```.
- console: Where to log background loading errors.  Must be a console compatible object.  Default is the JS console object.

### CachedLoader.loadAsync(check)
Returns a promise which resolves to an object with 2 properties:
- payload: The value loaded and transformed by the processor option
- loaded: True if new data was loaded, false if cached values were used

### CachedLoader.reset()
Resets all cached data and timers.

### CachedLoader Event: backgroundRefreshError
If an error occurs in the background refresh, this event is emitted with the error as the argument.  If there are NO listeners to this event, then an error is logged using ```options.console.warn```.


# Contributing

Any PRs are welcome but please stick to following the general style of the code and stick to [CoffeeScript](http://coffeescript.org/).  I know the opinions on CoffeeScript are...highly varied...I will not go into this debate here - this project is currently written in CoffeeScript and I ask you maintain that for any PRs.
