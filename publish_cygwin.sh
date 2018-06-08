#!/usr/bin/env bash

yarn install

mkdir bin
rm -rf ./dist
lein.bat dist
cp -r target/jlink bin/

if [ "$1" == "release" ]; then
  echo "Publishing Release"
  ./node_modules/.bin/electron-builder --publish always -w
else
  echo "Publishing Beta Version"
  ./node_modules/.bin/electron-builder -c electron-builder-beta.yml --publish always -w
fi
