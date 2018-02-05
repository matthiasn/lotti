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
cd ./bin/

wget https://cdn.azul.com/zulu/bin/zulu9.0.4.1-jdk9.0.4-macosx_x64.tar.gz
tar -xzf zulu9.0.4.1-jdk9.0.4-macosx_x64.tar.gz
rm zulu9.0.4.1-jdk9.0.4-macos_x64.tar.gz

cd ..
