url = require 'url'
class Util

Util::calculateScore  = (date, votes) ->
  now = Math.round(date.getTime() / 1000)
  seconds = now - 1331323254
  order = Math.log(votes) / Math.log(10)
  rawScore = order + seconds / 45000
  return Math.round(rawScore * 10000000) / 10000000 

Util::randomString = (length) ->  
  out = ""
  i = 0
  while i < length
    rnum = Math.floor(Math.random() * this.chars.length)
    out += this.chars.substring(rnum, rnum + 1)
    i++
  out 

Util::parseAssembly = (assembly) ->
  results = JSON.parse(assembly).results
  out = {}
  [ 'medium', 'large' ].forEach (size) ->
    out[size] = results["resize_#{size}"][0]
  if parseInt(out.large.meta.width) <= parseInt(out.medium.meta.width)
    out.large = out.medium
  for size, upload of out
    out[size] = url.parse(upload.url).pathname.substring(1)
  out

Util::chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXTZabcdefghijklmnopqrstuvwxyz"

module.exports = Util