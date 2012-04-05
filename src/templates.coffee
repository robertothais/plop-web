fs = require('fs')
path = require('path')
jade = require('jade')

class Templates
  constructor: -> 
    @cache = {}

  filename: (name) ->
    path.join process.cwd(), 'views', "#{name}.jade"

  readFile: (name) ->
    fs.readFileSync this.filename(name)

  compile: (name) ->
    filename = this.filename name
    jade.compile(this.readFile(name), filename: filename)
      templates: this

  render: (name) ->
    @cache[name] ||= this.compile(name)

  send: (name, res) ->        
    try
      res.send this.render(name)
    catch error
      if error.code is 'ENOENT' then res.send 404 else throw error

  partials: ->
    @cache.partials ||= JSON.stringify
      login:   this.render('login'),
      preview: this.render('preview')
      post:    this.render('post')


module.exports = new Templates
