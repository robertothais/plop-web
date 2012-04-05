mongoose = require 'mongoose'
redis    = require 'redis'
socketRedis = require 'socket.io/node_modules/redis'
url      = require 'url'
http     = require 'http'

class Config

  constructor: -> 
    @environment = process.env.NODE_ENV || 'development'
    this.initErrors()
    this.initMongo()
    this.initRedis()
    this.initFacebook()
    this.initGlobalAgent()
    this.socketConfig()

  initFacebook: ->
    @facebook = {}
    @facebook.app_id =     process.env.FACEBOOK_APP_ID || '302946899759152'
    @facebook.app_secret = process.env.FACEBOOK_APP_SECRET || '67f736184742334282b5a38d35694023'

  initMongo: ->
    mongoose.connect process.env.MONGO_URL || 'mongodb://localhost/plop'

  initRedis: ->   
    newClient = (socket=false) ->
      constructor = if socket then socketRedis else redis
      if process.env.REDIS_URL?
        redisUrl = url.parse process.env.REDIS_URL
        client = constructor.createClient redisUrl.port, redisUrl.hostname
        client.on 'error', process.reportError
        client.auth redisUrl.auth.split(":")[1]
        client
      else
        client = redis.createClient()
        client.on 'error', process.reportError
        client

    @redis = session: newClient()
    @redis.socket = {}
    for key in [ 'pub', 'sub', 'store' ]
      @redis.socket[key] = newClient true

  initErrors: ->
    unless @environment is 'development'
      @airbrake = require('airbrake').createClient 'ec998fc8de1c2584705784a07d381171'
      @airbrake.serviceHost = 'errbit.plop.pe'
      @airbrake.timeout = 60 * 1000
      @airbrake.handleExceptions()
    process.reportError = (err) =>
      console.error err
      if @airbrake
        @airbrake.notify err
        console.error 'Sent to Errbit'

  initGlobalAgent: ->
    http.globalAgent.maxSockets = Infinity

  socketConfig: ->
    @socket = {}
    @socket.logLevel = if @environment == 'development' then 3 else 1

global.config = new Config