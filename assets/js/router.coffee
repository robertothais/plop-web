# Routes DOM events to app events
class Plop.Router extends EventEmitter

  constructor: (@app) ->

    this.addEvent 'click', 'body:not(.modal-open) li.new-upload a', 'uploads:show'
    this.addEvent 'click', 'body.modal-open li.new-upload a', 'uploads:hide'

    this.addEvent 'click', 'body:not(.modal-open) li.login a', 'registration:show'
    this.addEvent 'click', 'body.modal-open li.login a', 'registration:hide'

    this.addEvent 'click', 'a.logout', 'logout', null, false

    this.addEvent 'click', 'a.brand', 'index:show'

    this.addEvent 'click', ['#posts', 'article.preview a.title'],   'post:show', this.postId
    this.addEvent 'click', ['#posts', 'article.preview img.image'], 'post:show', this.postId

    this.addEvent 'click', 'li.random a', 'post:show:random'

    this.addEvent 'click', '#tabs li:not(.active) a', 'tab:load', this.tabName
    
    this.addEvent 'click', ['#posts', '.plop.btn'], 'upvote:new', this.postId

    this.addEvent 'click', ['#posts', '.share.facebook'], 'share:facebook', this.postId
    this.addEvent 'click', ['#posts', '.share.twitter'], 'share:twitter', this.postId

  addEvent: (domEvent, baseSelector, appEvent, dataFun, preventDefault = true) ->
    app = @app
    [router, selector, data] = [this, null, null]
    [baseSelector, selector] = baseSelector if $.isArray baseSelector      
    $(baseSelector).on domEvent, selector, (event) ->            
      if typeof dataFun is 'function'
        data = dataFun.apply this, [event]
      Plop.Tracker.event('Router', appEvent)
      router.emit appEvent, data
      !preventDefault

  postId: ->
    $(this).parents('[data-post-id]').attr('data-post-id')

  tabName: ->
    $(this).parents('[data-tab-name]').attr('data-tab-name')