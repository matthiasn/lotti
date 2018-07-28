all: package

clean:
	lein clean

deps: clean
	lein deps

npm-deps: clean
	yarn install

test: deps
	lein test

sass:
	lein sass4clj once

cljs: deps npm-deps
	@echo Building ClojureScript:
	lein cljs-main
	lein cljs-renderer
	lein cljs-updater

electron: clean deps test sass cljs

directories:
	@echo Preparing target directories:
	mkdir -p bin
	rm -rf ./dist

jlink: clean test directories
	@echo Assembling UberJAR:
	lein jlink assemble

# replace symlinks, they lead to problems with electron-packager
# from: https://superuser.com/questions/303559/replace-symbolic-links-with-files
symlinks: jlink
	@echo Fixing symlinks:
	./fix_symlinks.sh

install: jlink electron directories
	@echo Installing...
	cp -r target/jlink bin/
	chmod -R +w bin/

package: install
	@echo Publishing beta...
	./node_modules/.bin/electron-builder -m

beta: install
	@echo Publishing beta - requires S3 credentials in ENV...
	./node_modules/.bin/electron-builder -c electron-builder-beta.yml --publish always -m

release: install
	@echo Publishing release - requires S3 credentials in ENV...
	./node_modules/.bin/electron-builder --publish always -m
