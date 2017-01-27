module.exports = (grunt) ->
  require('load-grunt-tasks') grunt
  grunt.initConfig
    watch:
      coffee:
        files: ['src/**/*.coffee']
        tasks: ['build']
    coffee:
      options:
        sourceMap: true
      default:
        files: [{
          expand: true
          cwd: 'src'
          src: ['**/*.coffee']
          dest: 'tasks'
          ext: '.js'
        }]
    clean:
      build: 'build'
  grunt.registerTask 'build', [
    'clean:build'
    'coffee'
  ]
  grunt.registerTask 'default', [
    'build'
    'watch'
  ]