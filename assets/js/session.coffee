class Plop.Session extends EventEmitter

  @className = 'Session'
  
  constructor: (@sid, @app) ->
    @navElem = $ 'ul.nav.session'

    this.resetReadyState()
    this.resetAuthenticationState true
    this.initFacebook()           

    this.on 'connect', => this.prepare()
    this.on 'disconnect', => this.resetReadyState()
      
    this.on 'session:ready', (remoteUser) => this.isReady remoteUser
    this.on 'session:notfound', => 
      this.resetReadyState()
      this.prepare()

    this.on 'login:success', (remoteUser) => this.isAuthenticated remoteUser
    this.on 'login:error', => 
      this.resetAuthenticationState()
      this.hideModal()
      FB.logout()

    this.on 'unauthenticated', => this.resetAuthenticationState()

    this.on 'karma:update', (karma) => this.updateKarma(karma)

    @app.router.on 'registration:show', (message, authFollowup) =>
      if typeof authFollowup == 'function'
        @authFollowup = authFollowup
      this.showModal(message) if !this.authenticated 

    @app.router.on 'logout', => FB.logout()

  prepare: ->
    this.emit 'session:prepare', @sid

  initFacebook: ->
    e = document.createElement 'script'
    e.id = 'facebook-jssdk'
    e.async = true
    e.src = document.location.protocol + '//connect.facebook.net/es_LA/all.js'
    document.getElementById('fb-root').appendChild e

    window.fbAsyncInit = =>
      FB.init
        appId: $("meta[property=fb\\:app_id]").attr('content')
        status: true
        xfbml: true

      FB.Event.subscribe 'auth.authResponseChange', (res) =>
         this.onAuthResponseChange res

  onAuthResponseChange: (res) ->    
    switch res.status
      when 'connected'
        $.when(@readyPromise).done =>
          # We only give it a 5 second window to cache remote sessions
          if @remoteUser and @remoteUser.facebookId is res.authResponse.userID and 
          new Date - @remoteUser.lastSetAt < 5000
            this.isAuthenticated()
          else
            this.showSpinner() if this.modalShown()
            this.emit 'login', res.authResponse.accessToken
            
      when 'not_authorized', 'unknown'
        this.emit 'logout' if @authenticated
        this.resetAuthenticationState()
    @authResponse = res

  isReady: (remoteUser) ->
    this.setRemoteUser remoteUser
    @readyDeferred.resolve()

  setRemoteUser: (remoteUser) ->
    if remoteUser?
      $.extend @remoteUser, remoteUser
      @remoteUser.lastSetAt = new Date

  saveUsername: (username, callback) ->
    this.emit 'username:save', username, (success, response) =>      
      if success
        this.emit('karma:get')
        this.updateUsername response 

      callback success, response
      
  isAuthenticated: (remoteUser) ->
    this.setRemoteUser remoteUser
    @authenticated = true
    this.hideModal()    
    @navElem.find('.login').hide()
    userElem = @navElem.find('.user')
    
    if @remoteUser.username
      userElem.find('.username')
        .text(@remoteUser.username)
        .show()
      userElem.find('.no-username')
        .hide()
    else
      userElem.find('.username').hide()
      userElem.find('.no-username').show()  

    userElem.show()    

    if @remoteUser.username
      this.emit('karma:get')

  updateKarma: (karma) ->
    @remoteUser.karma = karma
    @navElem.find('.karma')
      .text("(#{Plop.Util.addCommas(@remoteUser.karma)})")

  updateUsername: (username) ->
    @remoteUser.username = username
    @navElem.find('.username')
      .show()
      .text(@remoteUser.username)
    @navElem.find('.no-username')
      .hide()

  resetReadyState: ->
      @ready = false
      @readyDeferred = new $.Deferred
      @readyPromise  = @readyDeferred.promise()
      @readyDeferred.done => @ready = true

  resetAuthenticationState: (first = false) ->
    @authenticated = false
    @remoteUser = {}
    unless first
      @navElem.find('.user').hide()
      @navElem.find('.login').show()

  prepareModal: ->
    @modal = $(@app.templates.login).modal()

    @modal.find('.login').click =>
      FB.login()
      false

    @modal.on 'hidden', =>
      @navElem.find('.login').removeClass 'active'
      @modal.find('.modal-body p').hide()
      this.hideSpinner()
      if @authenticated
        @authFollowup() if @authFollowup
        @authFollowup = null

  showModal: (message) ->
    @navElem.find('.register').addClass 'active'
    if @modal then @modal.modal('show') else this.prepareModal()
    if message
      @modal.find('.modal-body p').show().text(message)

  showSpinner: ->
    @modal.find('.spin').show().spin
      lines: 13
      length: 7
      width: 4
      radius: 8
      rotate: 0
      trail: 60
      speed: 1.0

  hideSpinner: ->
    @modal.find('.spin').spin(false).hide()

  hideModal: ->
    if @modal then @modal.modal 'hide'
  
  modalShown: ->
    @modal and @modal.data('modal').isShown