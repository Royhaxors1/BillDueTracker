SHELL := /bin/bash

.PHONY: ios-verify ios-build

ios-verify:
	./scripts/ios_verify.sh

# Hard cutover: local build path always runs tests.
ios-build: ios-verify
