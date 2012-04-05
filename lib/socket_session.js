(function() {
  var SocketSession;

  SocketSession = (function() {

    function SocketSession(sessionStore, id, callback) {
      var _this = this;
      this.sessionStore = sessionStore;
      this.id = id;
      this.sessionStore.get(this.id, function(err, data) {
        _this.data = data || {};
        _this.unmarshal();
        return callback(err, _this.data);
      });
    }

    SocketSession.prototype.save = function(callback) {
      var _this = this;
      this.marshal();
      return this.sessionStore.set(this.id, this.data, function(err) {
        _this.unmarshal();
        if (callback != null) {
          return callback(err);
        } else {
          if (err) return process.reportError(err);
        }
      });
    };

    SocketSession.prototype.unmarshal = function() {
      var _this = this;
      delete this.data.cookie;
      return this.data.save = function(cb) {
        return _this.save(cb);
      };
    };

    SocketSession.prototype.marshal = function() {
      this.data.cookie = {};
      return delete this.data.save;
    };

    return SocketSession;

  })();

  module.exports = SocketSession;

}).call(this);
