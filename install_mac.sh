#!/usr/bin/env bash

curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | bash
source $HOME/.bashrc
nvm install 8.7

npm install -g electron
npm install -g electron-builder
npm install -g electron-cli
npm install -g electron-build-env
npm install -g electron-publisher-s3
npm install -g node-gyp
npm install -g yarn
npm install -g webpack

mkdir ./bin
