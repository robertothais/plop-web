require '../lib/config'
express     = require 'express'
templates   = require '../lib/templates'
Post        = require('../lib/post').model
SocketApp   = require '../lib/socket_app'
SocketRedisStore = require 'socket.io/lib/stores/redis'
ConnectRedisStore  = new require('connect-redis')(express)

sessionStore  = new ConnectRedisStore
  client: config.redis.session
  
app = express.createServer()
io  = require('socket.io').listen app

app.listen process.env.PORT

app.configure ->
  this.use express.logger('dev')
  # Redirect if www
  this.use (req, res, next) ->
    if req.headers.host and match = req.headers.host.match /^www\./
      res.redirect "http://#{req.headers.host.replace(match[0], "")}#{req.url}", 301
    else
      next()
  this.use express.responseTime()  
  this.use express.favicon "#{__dirname}/../assets/img/favicon.ico"  
  this.use require('connect-assets')
    servePath: 'http://static.plop.pe'
    detectChanges: false
  this.use express.cookieParser()
  this.set 'view options', layout: false
  this.set 'view engine', 'jade'
  this.enable 'view cache'
  this.use express.session
    secret: "178ce3955bc39def93274c384eec7b", 
    key: 'plop.sid'    
    store: sessionStore
    cookie:
      expires: false
  this.use express.errorHandler
    dumpExceptions: true
    showStack: (process.env.NODE_ENV == 'development')

io.configure ->
  store = new SocketRedisStore
    redisPub: config.redis.socket.pub
    redisSub: config.redis.socket.sub
    redisClient: config.redis.socket.store
  io.set 'store', store
  io.set 'log level', config.socket.logLevel
  io.set 'transports', [
    'websocket', 
    'htmlfile', 
    'xhr-polling', 
    'jsonp-polling' 
  ]
  io.enable 'browser client minification'
  io.enable 'browser client etag'
  io.enable 'browser client gzip'

app.get "/", (req, res) ->
  res.render 'index',
    title: '¡Plop! - Para que te caigas de risa'
    templates: templates
    sid: req.sessionID

app.get "/nuevo", (req, res) ->
  res.render 'index',
    title: '¡Plop! - Lo nuevo'
    templates: templates
    sid: req.sessionID

app.get "/templates/:template", (req, res) ->
  templates.send req.params.template, res

app.get "/errbit/test", (req, res) ->
  process.reportError new Error('My Test Error')
  res.send 200

app.get "/r/:shortCode", (req, res) ->
  Post.findOne(shortCode: req.params.shortCode)
    .populate('creator')
    .exec (err, doc) ->
      if err or !doc
        process.reportError err if err
        res.send(404)
      else
        res.render 'index', 
          post: doc
          templates: templates
          sid: req.sessionID

io.sockets.on 'connection', (socket) ->     
  new SocketApp(socket, sessionStore)