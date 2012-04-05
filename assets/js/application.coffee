#= require vendor/jquery
#= require vendor/bootstrap-tooltip
#= require_tree vendor
#= require_tree .

$ -> 
  Plop.application = new Plop.Application(Plop.sid)

class Plop.Application
  constructor: (sid) ->    
    @socket = io.connect()

    this.initTemplates()
    
    @router    = new Plop.Router(this)

    @session   = new Plop.Session(sid, this)
    @uploader  = new Plop.Uploader(this)
    @manager   = new Plop.PostManager(this)

    this.pipe 'connect',            to:   @session
    this.pipe 'disconnect',         to:   @session  

    this.pipe 'session:prepare',    from: @session
    this.pipe 'session:ready',      to:   @session
    this.pipe 'session:notfound',   to:   @session
    this.pipe 'session:error',      to:   @session  

    this.pipe 'login',              from: @session
    this.pipe 'login:success',      to:   @session
    this.pipe 'logout',             from: @session
    this.pipe 'karma:get',          from: @session
    this.pipe 'karma:update',       to:   @session
    this.pipe 'username:save',      from: @session

    this.pipe 'post:create',        from: @uploader

    this.pipe 'connect',            to:   @manager
    this.pipe 'posts:get',          from: @manager
    this.pipe 'post:get',           from: @manager
    this.pipe 'post:get:random',    from: @manager
    this.pipe 'post:created',       to:   @manager
    this.pipe 'upvote:create',      from: @manager
    this.pipe 'upvote:created',     to:   @manager
   
  pipe: (event, map) ->
    if map.hasOwnProperty 'to'
      receiver = map.to      
      @socket.on event, (args...) =>  
        Plop.Tracker.event('Socket', event, receiver.constructor.className)
        args.unshift event
        receiver.emit.apply receiver, args

    if map.hasOwnProperty 'from'
      source = map.from
      source.on event, (args...) =>
        Plop.Tracker.event(source.constructor.className, event, 'Socket')
        args.unshift event
        @socket.emit.apply @socket, args

  initTemplates: ->
    @templates = Plop.templates
    delete Plop.templates