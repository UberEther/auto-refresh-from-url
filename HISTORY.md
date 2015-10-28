- v0.2.0: Major rework (not backwards compatible)
    - Refactored into multiple independent loaders

- v0.1.1: Development (never released)
	- Minor readme updates
	- Do not throw error on refresh promise unless forced
	- Modify how request is promisified so we do not modify original object
	- Fix errors to use loaded res.request.href instead of @url
	- Allow HTTP 200 and 201 responses

- v0.1.0: Initial Release (10/6/2015)