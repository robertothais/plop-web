Plop.Tracker = 
  
  event: (category, action, label) ->
    obj = ['_trackEvent', category, action ]
    obj.push label if label

    _gaq.push obj
    if Plop.debug and console.debug?
      console.debug obj.slice(1).join(' -> ') 