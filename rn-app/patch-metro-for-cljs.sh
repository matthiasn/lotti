#!/usr/bin/env bash

# prevent metro-bundler applying code folding to our cljs output
sed -i .bak \
    's/(options.minify)/(options.minify \&\& !filename.match(\/release\\.ios\\.js\/))/' \
    ./node_modules/metro-bundler/src/JSTransformer/worker/index.js

# prevent metro-bundler applying minification to our cljs output
sed -i .bak \
    's/minify(filename, inputCode, sourceMap) {$/minify(filename, inputCode, sourceMap) { if (filename.match(\/release\\.ios\\.js\/)) { return { code: inputCode, map: sourceMap }; }/' \
    ./node_modules/metro-bundler/src/JSTransformer/worker/minify.js
