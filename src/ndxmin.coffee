'use strict'

module.exports = (grunt) ->
  async = require 'async'
  cheerio = require 'cheerio'
  adler32 = require 'adler-32'
  uglify = require 'uglify-js'
  cssmin = require 'cssmin'
  minify = require 'html-minifier'
  .minify
  curl = require 'curl'
  path = require 'path'
  fs = require 'fs'
  babel = require 'babel-core'
  grunt.registerMultiTask 'ndxmin', 'Minify stuff', ->
    done = @async()
    options = @options
      dir: process.cwd()
    destDir = path.join(options.dir, (if options.dest then options.dest else options.base))
    if not fs.existsSync destDir
      fs.mkdirSync destDir
    if not fs.existsSync path.join(destDir, 'app/')
      fs.mkdirSync path.join(destDir, 'app')
    readFile = (src, callback) ->
      if /^http:|^https:|^\/\//.test(src)
        if options.ignoreExternal
          callback true, ''
        else
          if /^\/\//.test(src)
            src = 'http:' + src
          curl.get src, (err, res, body) ->
            callback err, body
      else
        r = new RegExp '^[\/]*' + (options.base or '')
        src = src.replace r, ''
        filePath = path.join options.dir, (options.base or ''), src
        if fs.existsSync filePath
          txt = fs.readFileSync filePath, 'utf8'
          #console.log filePath
          #console.log txt
          callback null, txt
        else
          callback true, ''
    async.eachSeries @data.html, (file, fileCallback) ->
      filePath = path.join(options.dir, file)
      if fs.existsSync filePath
        blocks = []
        block = []
        html = fs.readFileSync filePath, 'utf8'
        $ = cheerio.load html
        for s in $('script')
          src = $(s).attr('src')
          block.type = 'script'
          block.push
            elem: s
            src: src
          next = $(s).next()[0]
          if not next or (next and (next.name isnt 'script' or next.attribs['ndx-ignore']))
            blocks.push block
            block = []
        for l in $('link[rel="stylesheet"]')
          src = $(l).attr('href')
          block.type = 'link'
          block.push
            elem: l
            src: src
          next = $(l).next()[0]
          if not next or (next and next.name isnt 'link')
            blocks.push block
            block = []
        async.eachSeries blocks, (block, blockCallback) ->
          txt = ''
          placeholder = null
          async.eachSeries block, (s, scriptCallback) ->
            readFile s.src, (err, response) ->
              if not err
                if not placeholder
                  placeholder = $(s.elem).replaceWith($('<placeholder></placeholder>'))
                else
                  $(s.elem).remove()
                txt += '\n' + response
              scriptCallback()
          , ->
            if txt.length
              outName = 'ndx.' + adler32.str(txt).toString().replace('-', 'm') + (if block.type is 'script' then '.js' else '.css')
              outPath = path.join destDir, 'app', outName
              if block.type is 'script' 
                len = txt.length
                #if options.uglify or options.babel
                #  
                txt = txt.replace /\/\/# sourceMappingURL=.*?\.map/gi, ''
                if options.babel
                  console.log 'babeling'
                  result = babel.transform txt,
                    presets: [[
                      'env',
                      targets:
                        browsers: ["last 2 versions", "ie >= 7"]
                      modules: false
                    ]]
                    plugins: ['angularjs-annotate']
                  txt = result.code
                if options.uglify
                  console.log 'uglifying'
                  result = uglify.minify txt, options.uglify
                  txt = result.code
                  console.log 'replaced', parseInt(txt.length/len * 100) + '%'
                if placeholder
                  $('placeholder').replaceWith($('<script src="app/' + outName + '"></script>'))
                fs.writeFileSync outPath, txt, 'utf8'
              else if block.type is 'link'
                result = cssmin txt
                $('placeholder').replaceWith($('<link rel="stylesheet" href="app/' + outName + '" />'))
                fs.writeFileSync outPath, result, 'utf8'
            blockCallback()
        , ->
          outhtml = $.html()#minify($.html())
          r = new RegExp '^[\/]*' + (options.base or '')
          file = file.replace r, ''
          fs.writeFileSync path.join(destDir, file), outhtml, 'utf8'
          fileCallback()
    , ->
      #console.log path.join(options.dir, @data.html[0])
      done()