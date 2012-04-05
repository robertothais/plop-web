(function() {
  var Post, SocketApp, SocketSession, User, async,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  Post = require('../lib/post').model;

  User = require('../lib/user').model;

  SocketSession = require('../lib/socket_session');

  async = require('async');

  SocketApp = (function() {

    function SocketApp(socket, sessionStore) {
      var _this = this;
      this.socket = socket;
      this.sessionStore = sessionStore;
      this.logout = __bind(this.logout, this);
      this.socket.on('session:prepare', function(sessionId) {
        return _this.socket.set('session.id', sessionId, function() {
          return _this.withSession(function(session) {
            return _this.socket.emit('session:ready', session.user);
          });
        });
      });
      this.socket.on('login', function(accessToken) {
        return _this.withSession(function(session) {
          return _this.login(session, accessToken);
        });
      });
      this.socket.on('logout', function() {
        return _this.authenticated(function(user, session) {
          return _this.logout(session);
        });
      });
      this.socket.on('username:save', function(username, callback) {
        return _this.authenticated(function(user, session) {
          return _this.saveUsername(user, session, username, callback);
        });
      });
      this.socket.on('karma:get', function() {
        return _this.authenticated(function(user) {
          return _this.socket.emit('karma:update', user.karma);
        });
      });
      this.socket.on('upvote:create', function(postId) {
        return _this.authenticated(function(user) {
          return _this.createUpvote(user, postId);
        });
      });
      this.socket.on('post:create', function(data) {
        return _this.authenticated(function(user, session) {
          return _this.createPost(user, data, session);
        });
      });
      this.socket.on('posts:get', function(query, callback) {
        return _this.getPosts(query, callback);
      });
      this.socket.on('post:get', function(id, callback) {
        return _this.getPost(id, callback);
      });
      this.socket.on('post:get:random', function(callback) {
        return _this.getRandomPost(callback);
      });
    }

    SocketApp.prototype.login = function(session, accessToken) {
      var _this = this;
      return User.authenticate(accessToken, function(err, user) {
        if (err) {
          process.reportError(err);
          return _this.socket.emit('login:failure');
        } else {
          session.user = {
            id: user.id,
            facebookId: user.facebookId,
            username: user.username
          };
          return session.save(function(err) {
            if (err) {
              process.reportError(err);
              return _this.socket.emit('login:error');
            } else {
              return _this.socket.emit('login:success', session.user);
            }
          });
        }
      });
    };

    SocketApp.prototype.logout = function(session) {
      delete session.user;
      return session.save();
    };

    SocketApp.prototype.createUpvote = function(user, postId) {
      var _this = this;
      return Post.upvote(user, postId, function(err, numAffected) {
        if (err) process.reportError(err);
        if (!err && numAffected > 0) {
          return _this.socket.emit('upvote:created', postId);
        }
      });
    };

    SocketApp.prototype.saveUsername = function(user, session, username, callback) {
      var _this = this;
      if (typeof username === 'string') username = username.toLowerCase();
      return User.setUsername(user, username, function(err) {
        if (err) {
          if (err.code === 11001) {
            return callback(false, 'duplicate');
          } else if (err.type = 'validation') {
            return callback(false, 'validation');
          } else {
            return process.reportError(err);
          }
        } else {
          callback(true, username);
          session.user.username = username;
          return session.save();
        }
      });
    };

    SocketApp.prototype.createPost = function(user, data, session) {
      var _this = this;
      if (!user.username) return;
      return Post.create({
        title: data.title,
        creator: user.id,
        assemblyUrl: data.assemblyUrl
      }, function(err, post) {
        if (err) {
          return process.reportError(err);
        } else {
          return _this.socket.emit('post:created', post.asJson({
            creator: user
          }));
        }
      });
    };

    SocketApp.prototype.getPosts = function(query, callback) {
      var sortField,
        _this = this;
      if (!(typeof query.limit === 'number' && typeof query.skip === 'number')) {
        return;
      }
      query.limit = Math.min(query.limit, 20);
      sortField = (function() {
        switch (query.tab) {
          case 'hot':
            return 'score';
          case 'new':
            return '_id';
          default:
            return 'hot';
        }
      })();
      return Post.find().populate('creator').slaveOk().limit(query.limit).skip(query.skip).sort(sortField, 'descending').exec(function(err, docs) {
        var posts;
        if (err) {
          process.reportError(err);
          return _this.socket.emit('posts:get:error');
        } else {
          posts = [];
          docs.forEach(function(doc) {
            return posts.push(doc.asJson());
          });
          return callback(posts);
        }
      });
    };

    SocketApp.prototype.getPost = function(shortCode, callback) {
      var _this = this;
      return Post.findOne({
        shortCode: shortCode
      }).populate('creator').exec(function(err, post) {
        if (err) {
          process.reportError(err);
          return _this.socket.emit('post:get:error');
        } else if (post) {
          return callback(post.asJson());
        }
      });
    };

    SocketApp.prototype.getRandomPost = function(callback) {
      var _this = this;
      return Post.random(function(err, post) {
        if (err) {
          process.reportError(err);
          return _this.socket.emit('post:get:error');
        } else {
          return callback(post.asJson());
        }
      });
    };

    SocketApp.prototype.withSession = function(callback) {
      var _this = this;
      return async.waterfall([
        function(next) {
          return _this.socket.get('session.id', function(err, sessionId) {
            if (!err && !(sessionId != null)) {
              return _this.socket.emit('session:notfound');
            } else {
              return next(err, sessionId);
            }
          });
        }, function(sessionId, next) {
          return new SocketSession(_this.sessionStore, sessionId, next);
        }
      ], function(err, session) {
        if (err) {
          process.reportError(err);
          return _this.socket.emit('session:error');
        } else {
          return callback(session);
        }
      });
    };

    SocketApp.prototype.authenticated = function(callback) {
      var _this = this;
      return async.waterfall([
        function(next) {
          return _this.withSession(function(session) {
            if (session.user == null) {
              return _this.socket.emit('unauthenticated');
            } else {
              return next(null, session);
            }
          });
        }, function(session, next) {
          return User.findById(session.user.id, function(err, user) {
            if (!err && !user) {
              return _this.socket.emit('unauthenticated');
            } else {
              return next(err, user, session);
            }
          });
        }
      ], function(err, user, session) {
        if (err) {
          process.reportError(err);
          return _this.socket.emit('session:error');
        } else {
          return callback(user, session);
        }
      });
    };

    return SocketApp;

  })();

  module.exports = SocketApp;

}).call(this);
