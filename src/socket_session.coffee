# Essentially we try to mock a Connect Session object
# This class is dependent on the connect-redis internal implementation.
# In particular, the only behavior that connect-redis expects from the 
# original Connect Session object is to have a 'cookie' key. On 'set'  it 
# checks for its maxAge attribute to set the ttl of the Redis entry. 
# If the attribute is blank, it defaults to a value of 1 day. 
# We stub this attribute and set no maxAge to trigger the default.
# TODO figure out a more elegant way to integrate with Connect sessions via socket.

class SocketSession

  constructor: (@sessionStore, @id, callback) -> 
    @sessionStore.get @id, (err, data) =>
      @data = (data || {})
      this.unmarshal()
      callback err, @data

  save: (callback)  ->
    this.marshal()      
    @sessionStore.set @id, @data, (err) =>
      this.unmarshal()
      if callback?
        callback err
      else      
        process.reportError err if err

  unmarshal: ->
    delete @data.cookie
    @data.save = (cb) => this.save cb

  marshal: ->
    @data.cookie = {}
    delete @data.save

module.exports = SocketSession