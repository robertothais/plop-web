class Plop.Util

  # Use only one to ensure images are cached by the browser
  # Todo store server index on image
  @assets = 
    baseUrl: 'assets{n}.plop.pe'
    pointer: 0
    max: 1
  
  @assetUrl = (key) ->
    @assets.pointer = (@assets.pointer % @assets.max) + 1
    host = @assets.baseUrl.replace '{n}', @assets.pointer
    "http://#{host}/#{key}"

  @addCommas = (nStr) ->
    nStr += ""
    x = nStr.split(".")
    x1 = x[0]
    x2 = (if x.length > 1 then "." + x[1] else "")
    rgx = /(\d+)(\d{3})/
    x1 = x1.replace(rgx, "$1" + "," + "$2")  while rgx.test(x1)
    x1 + x2

  @showPopup: (url, width=700, height= 370) -> 
    target = url || $(this).attr("href")
    height = $(this).attr("data-height") or height
    width = $(this).attr("data-width") or width
    name = (new Date).getTime() + "_popup"
    left = (screen.width/2)-(width/2)
    top = (screen.height/2)-(height/2)
    settings = "height=#{height},width=#{width},toolbar=no,top=#{top},left=#{left}"
    window.open target, name, settings
    false

  @delay: (ms, callback) -> setTimeout callback, ms

  @nextTick: (callback) -> this.delay 1, callback

  @proxy = (target, name, fn) ->
    target[name] = (args...) -> fn args...