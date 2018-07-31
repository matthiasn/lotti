# OS detection adapted from: https://gist.github.com/sighingnow/deee806603ec9274fd47
OSFLAG 	:=
LEIN 	:=
YARN := $(shell command -v yarn 2> /dev/null)
JLINK := $(shell command -v jlink 2> /dev/null)

ifeq ($(OS),Windows_NT)
	LEIN := $(shell command -v lein.bat 2> /dev/null)
	OSFLAG := -w
else
	LEIN := $(shell command -v lein 2> /dev/null)
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Linux)
		OSFLAG := -l
	endif
	ifeq ($(UNAME_S),Darwin)
		OSFLAG := -m
	endif
	ifeq ($(UNAME_S),CYGWIN_NT-10.0)
		LEIN := $(shell command -v lein.bat 2> /dev/null)
		OSFLAG := -w
	endif
endif

package: install package-only

build-deps:
ifndef LEIN
	$(error "Leiningen not found, please install from https://leiningen.org")
endif
ifndef YARN
	$(error "yarn not found, please install from https://yarnpkg.com")
endif
ifndef JLINK
	$(error "jlink not found, please install JDK10")
endif

clean: build-deps
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

package-only:
	@echo Building executable...
	./node_modules/.bin/electron-builder $(OSFLAG)

publish-beta:
	@echo Publishing beta - requires S3 credentials in ENV...
	./node_modules/.bin/electron-builder -c electron-builder-beta.yml --publish always $(OSFLAG)

beta: install publish-beta

release: install
	@echo Publishing release - requires S3 credentials in ENV...
	./node_modules/.bin/electron-builder --publish always $(OSFLAG)
