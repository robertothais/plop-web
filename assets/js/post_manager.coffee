class Plop.PostManager extends EventEmitter
  
  @className = 'PostManager'
  
  constructor: (@app) ->
    @ready = false
    @history = new Plop.History(this)
    @templates =
      preview: 
        html: @app.templates.preview
        map: null
      post:
        html: @app.templates.post
        map: null
    @batchSize = 10
    @cache = {}
    @states = {}
    @skip = 0
    @container = $ "#posts"

    @tabs = 
      hot: 
        title: 'Te vas a caer de la risa'
        path: '/'    
      new:
        title: 'Lo nuevo'
        path: '/nuevo'

    this.prepareMaps()

    this.on 'connect', =>
      @history.initialLoad() unless @ready

    this.once 'node:inserted', =>
      this.emit 'ready'
      @ready = true

    this.on 'ready', this.onReady

    this.on 'upvote:created', this.onUpvoteCreated

    #this.on 'post:shown', this.parsePlusOne
    this.on 'post:shown', this.parseXFBML
    this.on 'post:shown', (post) =>
      Plop.Tracker.event 'PostManager', 'post:shown', post.id

    this.on 'posts:appended', this.setWaypoint
    this.on 'posts:appended', =>
      Plop.Tracker.event 'PostManager', 'posts:appended', @currentTab

    this.on 'posts:nomore', =>
      $('body').addClass('no-more-posts')

    this.on 'posts:nomore', =>
      Plop.Tracker.event 'PostManager', 'posts:nomore', @currentTab

    this.on 'post:created', (post) =>
      this.once 'post:shown', =>
        Plop.Util.delay 1000, =>
          this.promptFacebookShare()
      this.receive post, true

    @app.router.on 'upvote:new', (id) =>
      if @app.session.authenticated 
        this.upvote id
      else 
        @app.router.emit 'registration:show', 'Tienes que entrar para poder votar', =>
          this.upvote id

    @app.router.on 'share:facebook', this.shareOnFacebook
    @app.router.on 'share:twitter', this.shareOnTwitter            

    @app.router.on 'index:show', =>
      this.loadTab 'hot'

    @app.router.on 'post:show', this.get

    @app.router.on 'tab:load', this.loadTab

    @app.session.on 'facebook:edge.create', this.upvoteFromLike

  onReady: => 
    $('#loader').hide()
    @app.router.on 'post:show:random', =>
      this.get '-random'
    this.observeScroll()

  nextBatch: (callback) ->
    this.emit 'posts:get', 
      skip: @skip 
      limit: @batchSize
      tab: (@loadingTab || @currentTab)
      (posts) => 
        callback() if callback
        this.append posts

  loadTab: (name, history = true) =>
    @skip = 0 
    @loadingTab = name
    this.nextBatch =>
      @loadingTab = null
      @currentTab = name      
      @currentPost = null
      this.pushHistory name if history
      @container.empty()
      this.activateTab @currentTab
      $('html,body').scrollTop 0

  activateTab: (tab) ->
    $('#tabs').find("li").removeClass 'active'
    $('#tabs').find("li[data-tab-name=#{tab}]").addClass 'active'
    @container.parent('.module').attr('data-tab', tab)

  get: (id, history = true, force = false) =>
    callback = (post) =>  
      this.receive post, history

    if id is '-random'
      this.emit 'post:get:random', callback
    else if @cache[id] and !force
      callback @cache[id]
    else
      this.emit 'post:get', id, callback

  show: (post) =>    
    html = this.render post, 'post'
    node = $ html
    this.prepareForInsert node, 'post'    
    @currentTab = null
    @container.empty()
    this.setCurrentPost(post, node)    
    this.insert node
    $('body').addClass 'showing-post' 
    $('body').removeClass('no-more-posts')
    window.scrollTo(0,0)   
    this.emit 'post:shown', post
    
  append: (data) =>
    postHtml = []
    $.each data, (i, post) => 
      this.store post
      postHtml.push this.render post, 'preview'
    node = $ postHtml.join('')
    this.prepareForInsert node, 'preview'
    $('body').removeClass 'showing-post'
    $('body').removeClass 'no-more-posts'
    this.insert node
    @skip += data.length
    if data.length
      this.emit 'posts:appended'
    else
      this.emit 'posts:nomore'

  receive: (post, history) =>
    this.store post
    this.saveState() if history
    this.pushHistory post if history
    this.show post, history

  insert: (node) ->
    node.appendTo @container
    this.emit 'node:inserted'

  upvote: (id) =>
    this.emit 'upvote:create', id

  onUpvoteCreated: (id) =>
    @cache[id].votes++
    $("[data-post-id=#{id}]").find('.votes').text(@cache[id].votes)

  render: (post, templateName) ->    
    data = this.prepareForRender post, templateName
    template = @templates[templateName]
    Plates.bind template.html, data, template.map

  prepareForRender: (post, template) ->
    data = $.extend {}, post
    if template is 'preview'
      data.imageUrl = Plop.Util.assetUrl post.images.medium   
    else if template is 'post'
      data.imageUrl = Plop.Util.assetUrl post.images.large
    data.url = this.url post.id 
    data.votes = Plop.Util.addCommas data.votes
    $.extend data, post.creator

  upvoteFromLike: (url) =>
    return unless @app.session.authenticated
    data = this.parseUrl url
    if data.isPost
      this.upvote data.postId

  setCurrentPost: (post, node) ->
    @currentPost =
      data: post
      node: node

  prepareForInsert: (node, template) ->
    node.find('.timeago').timeago()

  parseXFBML: =>
    FB.XFBML.parse @currentPost.node.get(0) if FB?

  parsePlusOne: =>
    unless @plusOnePromise?
      window.___gcfg = lang: 'es-419', parsetags: 'explicit'
      @plusOnePromise = $.getScript 'https://apis.google.com/js/plusone.js'

    $.when(@plusOnePromise).done =>
      gapi.plusone.render @currentPost.node.find('.g-plusone').get(0),
        size: 'medium'

  pushHistory: (arg) ->
    switch typeof arg 
      # post
      when 'object' 
        post = arg   
        History.pushState null,
          this.makeTitle post.title
          this.url(post.id) 
      # tab
      when 'string'
        tab = @tabs[arg]
        History.pushState null,
          this.makeTitle tab.title
          tab.path

  store: (post) ->
    @cache[post.id] = post

  url: (id) ->
    "http://#{window.location.host}#{this.path(id)}"

  path: (id) ->
    "/r/#{@cache[id].id}"

  saveState:  ->
    return if @currentPost
    ids = [] 
    @container.find('.preview').each ->
      ids.push $(this).attr('data-post-id')
    @states[History.getState().id] = 
      collection: ids
      scrollTop:$(window).scrollTop()
      tab: @currentTab

  restoreState: (id) ->
    state = @states[id]
    return unless state
    previousState = History.getStateByIndex -2
    return unless previousState
    url = this.parseUrl previousState.cleanUrl
    return unless url.isPost or (state.tab? and @currentTab != state.tab)
    data = []    
    for id in state.collection
      data.push @cache[id]
    @container.empty()
    this.append data
    @currentPost = null
    @currentTab = state.tab
    this.activateTab @currentTab
    # If we're returning from a post go back to the
    # saved scrollTop
    if url.postId?
      $('html,body').scrollTop(state.scrollTop)
    @skip = state.collection.length

  makeTitle: (sub) ->
    "¡Plop! - #{sub}"

  shareOnFacebook: (id) =>
    FB.ui
      method: 'feed'
      link: this.url(id)
      name: @cache[id].title
      picture: Plop.Util.assetUrl @cache[id].images.medium
      caption: 'Esto y más en ¡Plop!'
      display: (if @currentPost? then 'dialog' else 'popup')
      (response) =>
        Plop.log(response)

  shareOnTwitter: (id) =>
    params = 
      url: this.url(id)
      via: 'plop_pe'
      text: @cache[id].title
      related: 'plop_pe:Te vas a caer de la risa'
    Plop.Util.showPopup "https://twitter.com/share?#{$.param(params)}"

  promptFacebookShare: ->
    shareButton = $ '.share.facebook'
    shareButton.popover
      placement: 'right'
      trigger: 'manual'
      content: 'Rumbo a la primera página!'
      title: 'Comparte tu imagen en Facebook'
    shareButton.popover('show')
    popover = shareButton.data('popover')
    # Maybe add a catch for ESC
    $(document).one 'mousedown', -> popover.hide()
    $(window).one 'statechange', -> popover.hide()

  parseUrl: (url) ->
    out = {}
    # Check if we have a post
    path = this.getPath(url) || "/"    
    if match = path.match /\/r\/[A-Za-z0-9]+$/
      out.isPost = true
      out.postId = match[0].replace("/r/", "")
      return out
    for name, data of @tabs 
      if data.path is path
        out.isTab = true
        out.tab = name
        return out
    return out

  getPath: (urlString) ->
    url = $.parseUrl urlString
    if url.anchor
      if state = History.extractState url.anchor, true
        return $.parseUrl(state.url).path
    url.path

  prepareMaps: ->
    for type in ['preview', 'post']
      map = @templates[type].map = Plates.Map create: true
      map.class('title').to 'title'
      map.class('username').to 'username'
      map.class('votes').to 'votes'    
      map.class('timeago').to('createdAt').as 'datetime'
      map.class('image').to('imageUrl').as 'src' 
      map.class(type).to('id').as 'data-post-id'
    @templates.post.map.class('fb-comments').to('url').as 'data-href'
    @templates.post.map.class('fb-like').to('url').as 'data-href'
    @templates.preview.map.class('url').to('url').as 'href'

  setWaypoint: =>
    callback = (event, direction) => 
      if direction is 'down' and @currentTab
        this.nextBatch()
    Plop.Util.delay 500, ->
      $('.preview:last-child').waypoint callback, 
        offset: 'bottom-in-view'
        onlyOnScroll: true
        triggerOnce: true

  observeScroll: ->
    elem = $('#back-to-top')
    $(window).scroll ->
      if $(this).scrollTop() > 1000
        elem.removeClass('offscreen')
      else         
        if !elem.hasClass('offscreen')
          elem.addClass('offscreen')
    elem.click -> $('html,body').scrollTop 0