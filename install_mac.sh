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

wget https://cdn.azul.com/zulu/bin/zulu8.27.0.7-jdk8.0.162-macosx_x64.zip
unzip zulu8.27.0.7-jdk8.0.162-macosx_x64.zip
rm zulu8.27.0.7-jdk8.0.162-macosx_x64.zip
mv zulu8.27.0.7-jdk8.0.162-macosx_x64 zulu8-mac_x64

# fix for update fail issue
chmod -R -v u+w zulu8-mac_x64

cd ..
