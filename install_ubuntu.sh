#!/bin/bash

sudo add-apt-repository ppa:linuxuprising/java
sudo apt-get update
sudo apt-get install oracle-java10-installer
sudo apt-get install oracle-java10-set-default
sudo apt-get install python2.7
sudo apt-get install make
sudo apt-get install g++
sudo apt-get install icnsutils
sudo apt-get install graphicsmagick
sudo apt-get install libx11-dev
sudo apt-get install libxkbfile-dev

wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash
source $HOME/.bashrc
nvm install 8.9

npm install -g electron
npm install -g electron-builder
npm install -g electron-cli
npm install -g electron-build-env
npm install -g electron-publisher-s3
npm install -g node-gyp
npm install -g yarn
npm install -g webpack
