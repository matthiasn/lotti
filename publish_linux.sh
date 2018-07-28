#!/usr/bin/env bash

yarn install

mkdir bin
rm -rf ./dist
lein dist

# replace symlinks, they lead to problems with electron-packager
# from: https://superuser.com/questions/303559/replace-symbolic-links-with-files
cd target
tar -hcf - jlink | tar xf - -C ../bin/
cd ..

chmod -R +w bin/

ELECTRON_BUILDER_COMPRESSION_LEVEL=3

if [ "$1" == "release" ]; then
  echo "Publishing Release"
  electron-builder --publish always -l AppImage
else
  echo "Publishing Beta Version"
  electron-builder -c electron-builder-beta.yml --publish always -l AppImage
fi
