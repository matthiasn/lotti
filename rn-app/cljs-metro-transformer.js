/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 * Note: This is a fork of the fb-specific transform.js
 *
 * 2017-07-26
 * Forked from: https://github.com/mjmeintjes/boot-react-native/blob/f7efbeb0881f9047c04c99f4767f5a1c279b7a3c/resources/mattsum/boot_rn/js/cljs-rn-transformer.js
 */
'use strict';

const fs = require('fs');
const transformer = require('metro-bundler/src/transformer');

function customTransform(code, filename) {
  console.log("Generating sourcemap for " + filename);
  var map = fs.readFileSync(filename + '.map', {encoding: 'utf8'});
  var sourceMap = JSON.parse(map);

  var sourcesContent = [];
  sourceMap.sources.forEach(function(path) {
    var sourcePath = __dirname + '/' + path;
    try {
      // try and find the corresponding `.cljs` file first
      sourcesContent.push(fs.readFileSync(sourcePath.replace('.js', '.cljs'), 'utf8'));
    } catch (e) {
      // otherwise fallback to whatever is listed as the source
      sourcesContent.push(fs.readFileSync(sourcePath, 'utf8'));
    }
  });
  sourceMap.sourcesContent = sourcesContent;

  return {
    filename: filename,
    code: code.replace("# sourceMappingURL=", ""),
    map: sourceMap
  };
}

function emptyTransform(code, filename) {
  return {
    filename: filename,
    code: code
  };
}

exports.transform = function (data) {
  console.log('using custom transform for file:', data.filename);
  return emptyTransform(data.src, data.filename);
};
