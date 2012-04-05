class Plop.History
  
  constructor: (@manager) ->
    $(window).on 'statechange', this.onStateChange
    @history = window.History

  initialLoad: =>
    # For HTML 4 browsers - we only want hash tags built over the base URL.
    # Redirect if otherwise.
    if @history.emulated.pushState and @history.getHash() and !@history.isTraditionalAnchor(window.location.href) and window.location.pathname != '/'
        intendedPath = @manager.getPath window.location.href
        window.location = intendedPath
        return

    url = @manager.parseUrl window.location.href

    pushState = false

    # Check if the data on the DOM corresponds to the URL, since if we're on a native pushState
    # browser and History.js detects an HTML 4 hash tag in the location bar, it will re-write 
    # it with a replaceState
    if Plop.load? 
      if Plop.load.id is url.postId
        @manager.store Plop.load
        @manager.show Plop.load, false
        return
      else
        # The location was re-written, push a new state when loading
        # TODO: use a replaceState instead of pushState - will need to change 
        # Not critical since this is an edge case: (HTML 4 link with post in hash
        # and another post in the path opened in an HTML 5 browser)
        pushState = true

    if url.isPost
       @manager.get url.postId, pushState
    else if url.isTab
        @manager.loadTab url.tab, pushState
    else
      @manager.loadTab 'hot', pushState

  onStateChange: (event) =>
    state = @history.getState()
    Plop.Tracker.event('History', 'statechange')
    url = @manager.parseUrl state.url
    if @manager.states[state.id]
      @manager.restoreState state.id
    else if url.isTab
      @manager.loadTab url.tab, false
    else if url.isPost
      @manager.get url.postId, false