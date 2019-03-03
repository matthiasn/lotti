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

deps-mac:
	npm install -g electron
	npm install -g electron-builder
	npm install -g electron-cli
	npm install -g electron-build-env
	npm install -g node-gyp
	npm install -g yarn
	npm install -g webpack
	mkdir ./bin

deps-ubuntu:
	sudo apt-get update
	sudo apt-get install python2.7
	sudo apt-get install make
	sudo apt-get install g++
	sudo apt-get install icnsutils
	sudo apt-get install graphicsmagick
	sudo apt-get install libx11-dev
	sudo apt-get install libxkbfile-dev
	sudo apt-get install libgconf-2-4
	npm install -g electron
	npm install -g electron-builder@20.38.5
	npm install -g electron-cli
	npm install -g electron-build-env
	npm install -g node-gyp
	npm install -g yarn
	npm install -g webpack
    mkdir ./bin

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
	@rm -rf ./dist
	@eval $(LEIN) clean
	@rm -f ./yarn.lock

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

figwheel:
	@lein cljs-figwheel

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
symlinks:
	@echo Fixing symlinks...
	tar -hcf - target/jlink | tar xf - -C bin/
	rm -rf bin/jlink
	mv bin/target/jlink/ bin/
	chmod -R ugo+w bin/jlink/legal/

install: jlink electron symlinks

package-only:
	@echo Building executable...
	./node_modules/.bin/electron-builder $(OSFLAG)

publish-github:
	@echo Publishing to GitHub Releases - requires GH_TOKEN in ENV...
	./node_modules/.bin/electron-builder -c electron-builder.yml --publish always $(OSFLAG)

release: install publish-github
