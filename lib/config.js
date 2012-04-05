(function() {
  var Config, mongoose, redis, socketRedis, url;

  mongoose = require('mongoose');

  redis = require('redis');

  socketRedis = require('socket.io/node_modules/redis');

  url = require('url');

  Config = (function() {

    function Config() {
      this.environment = process.env.NODE_ENV || 'development';
      this.initErrors();
      this.initMongo();
      this.initRedis();
      this.initFacebook();
      this.socketConfig();
    }

    Config.prototype.initFacebook = function() {
      this.facebook = {};
      this.facebook.app_id = process.env.FACEBOOK_APP_ID || '302946899759152';
      return this.facebook.app_secret = process.env.FACEBOOK_APP_SECRET || '67f736184742334282b5a38d35694023';
    };

    Config.prototype.initMongo = function() {
      return mongoose.connect(process.env.MONGO_URL || 'mongodb://localhost/plop');
    };

    Config.prototype.initRedis = function() {
      var key, newClient, _i, _len, _ref, _results;
      newClient = function(socket) {
        var client, constructor, redisUrl;
        if (socket == null) socket = false;
        constructor = socket ? socketRedis : redis;
        if (process.env.REDIS_URL != null) {
          redisUrl = url.parse(process.env.REDIS_URL);
          client = constructor.createClient(redisUrl.port, redisUrl.hostname);
          client.on('error', process.reportError);
          client.auth(redisUrl.auth.split(":")[1]);
          return client;
        } else {
          client = redis.createClient();
          client.on('error', process.reportError);
          return client;
        }
      };
      this.redis = {
        session: newClient()
      };
      this.redis.socket = {};
      _ref = ['pub', 'sub', 'store'];
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        key = _ref[_i];
        _results.push(this.redis.socket[key] = newClient(true));
      }
      return _results;
    };

    Config.prototype.initErrors = function() {
      var _this = this;
      if (this.environment !== 'development') {
        this.airbrake = require('airbrake').createClient('ec998fc8de1c2584705784a07d381171');
        this.airbrake.serviceHost = 'errbit.plop.pe';
        this.airbrake.timeout = 60 * 1000;
        this.airbrake.handleExceptions();
      }
      return process.reportError = function(err) {
        console.error(err);
        if (_this.airbrake) {
          _this.airbrake.notify(err);
          return console.error('Sent to Errbit');
        }
      };
    };

    Config.prototype.socketConfig = function() {
      this.socket = {};
      return this.socket.logLevel = this.environment === 'development' ? 3 : 1;
    };

    return Config;

  })();

  global.config = new Config;

}).call(this);
