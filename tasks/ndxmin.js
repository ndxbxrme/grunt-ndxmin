(function() {
  'use strict';
  module.exports = function(grunt) {
    var adler32, async, cheerio, cssmin, curl, fs, minify, ngmin, path, uglify;
    async = require('async');
    cheerio = require('cheerio');
    adler32 = require('adler-32');
    uglify = require('uglify-js');
    cssmin = require('cssmin');
    minify = require('html-minifier').minify;
    ngmin = require('ngmin');
    curl = require('curl');
    path = require('path');
    fs = require('fs');
    return grunt.registerMultiTask('ndxmin', 'Minify stuff', function() {
      var destDir, done, options, readFile;
      done = this.async();
      options = this.options({
        dir: process.cwd()
      });
      console.log(options.dir, options.dest, options.base);
      destDir = path.join(options.dir, (options.dest ? options.dest : options.base));
      if (!fs.existsSync(destDir)) {
        fs.mkdirSync(destDir);
      }
      if (!fs.existsSync(path.join(destDir, 'app/'))) {
        fs.mkdirSync(path.join(destDir, 'app'));
      }
      readFile = function(src, callback) {
        var filePath, r, txt;
        if (/^http:|^https:|^\/\//.test(src)) {
          if (options.ignoreExternal) {
            return callback(true, '');
          } else {
            if (/^\/\//.test(src)) {
              src = 'http:' + src;
            }
            return curl.get(src, function(err, res, body) {
              return callback(err, body);
            });
          }
        } else {
          r = new RegExp('^[\/]*' + (options.base || ''));
          src = src.replace(r, '');
          filePath = path.join(options.dir, options.base || '', src);
          if (fs.existsSync(filePath)) {
            txt = fs.readFileSync(filePath, 'utf8');
            return callback(null, txt);
          } else {
            return callback(true, '');
          }
        }
      };
      return async.eachSeries(this.data.html, function(file, fileCallback) {
        var $, block, blocks, filePath, html, i, j, l, len, len1, next, ref, ref1, s, src;
        filePath = path.join(options.dir, file);
        if (fs.existsSync(filePath)) {
          blocks = [];
          block = [];
          html = fs.readFileSync(filePath, 'utf8');
          $ = cheerio.load(html);
          ref = $('script');
          for (i = 0, len = ref.length; i < len; i++) {
            s = ref[i];
            src = $(s).attr('src');
            block.type = 'script';
            block.push({
              elem: s,
              src: src
            });
            next = $(s).next()[0];
            if (!next || (next && next.name !== 'script')) {
              blocks.push(block);
              block = [];
            }
          }
          ref1 = $('link[rel="stylesheet"]');
          for (j = 0, len1 = ref1.length; j < len1; j++) {
            l = ref1[j];
            src = $(l).attr('href');
            block.type = 'link';
            block.push({
              elem: l,
              src: src
            });
            next = $(l).next()[0];
            if (!next || (next && next.name !== 'link')) {
              blocks.push(block);
              block = [];
            }
          }
          return async.eachSeries(blocks, function(block, blockCallback) {
            var placeholder, txt;
            txt = '';
            placeholder = null;
            return async.eachSeries(block, function(s, scriptCallback) {
              return readFile(s.src, function(err, response) {
                if (!err) {
                  if (!placeholder) {
                    placeholder = $(s.elem).replaceWith($('<placeholder></placeholder>'));
                  } else {
                    $(s.elem).remove();
                  }
                  txt += '\n' + response;
                }
                return scriptCallback();
              });
            }, function() {
              var outName, outPath, result;
              if (txt.length) {
                outName = 'ndx.' + adler32.str(txt).toString().replace('-', 'm') + (block.type === 'script' ? '.js' : '.css');
                outPath = path.join(destDir, 'app', outName);
                if (block.type === 'script') {
                  txt = ngmin.annotate(txt);
                  result = {
                    code: txt
                  };
                  if (placeholder) {
                    $('placeholder').replaceWith($('<script src="app/' + outName + '"></script>'));
                  }
                  fs.writeFileSync(outPath, result.code, 'utf8');
                } else if (block.type === 'link') {
                  result = cssmin(txt);
                  $('placeholder').replaceWith($('<link rel="stylesheet" href="app/' + outName + '" />'));
                  fs.writeFileSync(outPath, result, 'utf8');
                }
              }
              return blockCallback();
            });
          }, function() {
            var outhtml, r;
            outhtml = minify($.html());
            r = new RegExp('^[\/]*' + (options.base || ''));
            file = file.replace(r, '');
            fs.writeFileSync(path.join(destDir, file), outhtml, 'utf8');
            return fileCallback();
          });
        }
      }, function() {
        return done();
      });
    });
  };

}).call(this);

//# sourceMappingURL=ndxmin.js.map
