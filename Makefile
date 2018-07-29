# OS detection adapted from: https://gist.github.com/sighingnow/deee806603ec9274fd47
OSFLAG 	:=
LEIN 	:=
ifeq ($(OS),Windows_NT)
	LEIN := lein.bat
	OSFLAG := -w
else
	LEIN := lein
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Linux)
		OSFLAG := -l
	endif
	ifeq ($(UNAME_S),Darwin)
		OSFLAG := -m
	endif
endif

all: package

clean:
	@echo Cleaning up...
	@rm -rf ./bin
	@eval $(LEIN) clean

deps: clean
	@echo Fetching Leiningen dependencies...
	@eval $(LEIN) deps

npm-deps: clean
	@echo Fetching NPM dependencies...
	@yarn install

test: deps
	@echo Running Clojure tests...
	@eval $(LEIN) test

sass:
	@echo Building CSS...
	@eval $(LEIN) sass4clj once

cljs: deps npm-deps
	@echo Building ClojureScript for main electron process...
	@eval $(LEIN) cljs-main
	@echo Building ClojureScript for electron renderer process...
	@eval $(LEIN) cljs-renderer
	@echo Building ClojureScript for electron updater process...
	@eval $(LEIN) cljs-updater

electron: clean deps test sass cljs

directories:
	@echo Preparing target directories...
	@mkdir -p bin
	@chmod -R +w bin/
	@rm -rf ./dist

jlink: clean test directories
	@echo Assembling UberJAR...
	@eval $(LEIN) jlink assemble

# replace symlinks, they lead to problems with electron-packager
# from: https://superuser.com/questions/303559/replace-symbolic-links-with-files
symlinks: jlink
	@echo Fixing symlinks...
	./fix_symlinks.sh

install: jlink electron symlinks

package: install
	@echo Building executable...
	./node_modules/.bin/electron-builder $(OSFLAG)

beta: install
	@echo Publishing beta - requires S3 credentials in ENV...
	./node_modules/.bin/electron-builder -c electron-builder-beta.yml --publish always -m

release: install
	@echo Publishing release - requires S3 credentials in ENV...
	./node_modules/.bin/electron-builder --publish always -m
