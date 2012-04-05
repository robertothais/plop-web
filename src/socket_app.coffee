Post      = require('../lib/post').model
User      = require('../lib/user').model
SocketSession = require '../lib/socket_session'
async    =  require 'async'

class SocketApp
  
  constructor: (@socket, @sessionStore) ->
    @socket.on 'session:prepare', (sessionId) =>
      @socket.set 'session.id', sessionId, =>
        this.withSession (session) =>
          @socket.emit 'session:ready', session.user

    @socket.on 'login', (accessToken) =>
      this.withSession (session) =>
        this.login session, accessToken

    @socket.on 'logout', =>
      this.authenticated (user, session) =>
        this.logout session

    @socket.on 'username:save', (username, callback) =>
      this.authenticated (user, session) =>
        this.saveUsername user, session, username, callback

    @socket.on 'karma:get', =>
      this.authenticated (user) =>
        @socket.emit 'karma:update', user.karma

    @socket.on 'upvote:create', (postId) =>
      this.authenticated (user) =>
        this.createUpvote user, postId

    @socket.on 'post:create', (data) =>
      this.authenticated (user, session) =>        
        this.createPost user, data, session

    @socket.on 'posts:get', (query, callback) =>
      this.getPosts query, callback

    @socket.on 'post:get', (id, callback) =>
      this.getPost id, callback

    @socket.on 'post:get:random', (callback) =>
      this.getRandomPost callback

  login: (session, accessToken) ->
    User.authenticate accessToken, (err, user) =>
      if err 
        process.reportError err
        @socket.emit 'login:failure'
      else
        session.user =
          id: user.id
          facebookId: user.facebookId
          username: user.username
          
        session.save (err) =>
          if err
            process.reportError err
            @socket.emit 'login:error'
          else
            @socket.emit 'login:success', session.user

  logout: (session) =>
    delete session.user
    session.save()

  createUpvote: (user, postId) ->
    Post.upvote user, postId, (err, numAffected) =>
      if err
        process.reportError err
      if !err and numAffected > 0
        @socket.emit 'upvote:created', postId        

  saveUsername: (user, session, username, callback) ->
    username = username.toLowerCase() if typeof username is 'string'
    User.setUsername user, username, (err) =>
      # The only situation in which we should report an error is
      # on a duplicate. Otherwise, the client should have taken
      # care of validation
      if err
        if err.code is 11001
          callback false, 'duplicate'
        else if err.type = 'validation'
          callback false, 'validation'
        else
          process.reportError err
      else
        callback true, username
        session.user.username = username
        session.save()

  createPost: (user, data, session) ->
    return unless user.username
    Post.create 
      title: data.title, 
      creator: user.id,
      assemblyUrl: data.assemblyUrl
      (err, post) => 
        # Will send validation errors too, since these
        # should be avoided by the client
        if err
          process.reportError err
        else
          @socket.emit 'post:created', post.asJson
            creator: user

  getPosts: (query, callback) ->
    return unless typeof query.limit == 'number' and  typeof query.skip  == 'number'      
    query.limit = Math.min query.limit, 20
    sortField = switch query.tab
      when 'hot' then 'score'
      when 'new' then '_id'
      else 'hot'
    Post.find()
    .populate('creator')
    .slaveOk()
    .limit(query.limit)        
    .skip(query.skip)
    .sort(sortField, 'descending')
    .exec (err, docs) =>
      if err
        process.reportError err
        @socket.emit 'posts:get:error'
      else
        posts = [] 
        docs.forEach (doc) -> posts.push doc.asJson()
        callback posts

  getPost: (shortCode, callback) ->
    Post.findOne(shortCode: shortCode)
      .populate('creator')
      .exec (err, post) =>
        if err
          process.reportError err
          @socket.emit 'post:get:error'
        else if post
          callback post.asJson()

  getRandomPost: (callback) ->
    Post.random (err, post) =>
      if err
        process.reportError err
        @socket.emit 'post:get:error'
      else
        callback post.asJson()

  withSession: (callback) ->
    async.waterfall [
      (next) =>
        @socket.get 'session.id', (err, sessionId) =>
          if !err and !sessionId?
            @socket.emit 'session:notfound'
          else
            next err, sessionId
      ,
      (sessionId, next) =>
        new SocketSession @sessionStore, sessionId, next
    ], (err, session) =>
      if err
        process.reportError err
        @socket.emit 'session:error'
      else
        callback session

  authenticated: (callback) ->
    async.waterfall [
      (next) =>
        this.withSession (session) =>
          unless session.user?
            @socket.emit 'unauthenticated'
          else
            next null, session
      ,
      (session, next) =>
        User.findById session.user.id, (err, user) =>
          if !err and !user
            @socket.emit 'unauthenticated'
          else
            next err, user, session
    ], (err, user, session) =>
      if err
        process.reportError err
        @socket.emit 'session:error'
      else
        callback user, session

module.exports = SocketApp