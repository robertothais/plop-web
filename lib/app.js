(function() {
  var ConnectRedisStore, Post, SocketApp, SocketRedisStore, app, express, io, sessionStore, templates;

  require('../lib/config');

  express = require('express');

  templates = require('../lib/templates');

  Post = require('../lib/post').model;

  SocketApp = require('../lib/socket_app');

  SocketRedisStore = require('socket.io/lib/stores/redis');

  ConnectRedisStore = new require('connect-redis')(express);

  sessionStore = new ConnectRedisStore({
    client: config.redis.session
  });

  app = express.createServer();

  io = require('socket.io').listen(app);

  app.listen(process.env.PORT);

  app.configure(function() {
    this.use(express.logger('dev'));
    this.use(function(req, res, next) {
      var match;
      if (req.headers.host && (match = req.headers.host.match(/^www\./))) {
        return res.redirect("http://" + (req.headers.host.replace(match[0], "")) + req.url, 301);
      } else {
        return next();
      }
    });
    this.use(express.responseTime());
    this.use(express.favicon("" + __dirname + "/../assets/img/favicon.ico"));
    this.use(require('connect-assets')({
      servePath: 'http://static.plop.pe',
      detectChanges: false
    }));
    this.use(express.cookieParser());
    this.set('view options', {
      layout: false
    });
    this.set('view engine', 'jade');
    this.enable('view cache');
    this.use(express.session({
      secret: "178ce3955bc39def93274c384eec7b",
      key: 'plop.sid',
      store: sessionStore,
      cookie: {
        expires: false
      }
    }));
    return this.use(express.errorHandler({
      dumpExceptions: true,
      showStack: process.env.NODE_ENV === 'development'
    }));
  });

  io.configure(function() {
    var store;
    store = new SocketRedisStore({
      redisPub: config.redis.socket.pub,
      redisSub: config.redis.socket.sub,
      redisClient: config.redis.socket.store
    });
    io.set('store', store);
    io.set('log level', config.socket.logLevel);
    io.set('transports', ['websocket', 'htmlfile', 'xhr-polling', 'jsonp-polling']);
    io.enable('browser client minification');
    io.enable('browser client etag');
    return io.enable('browser client gzip');
  });

  app.get("/", function(req, res) {
    return res.render('index', {
      title: '¡Plop! - Para que te caigas de risa',
      templates: templates,
      sid: req.sessionID
    });
  });

  app.get("/nuevo", function(req, res) {
    return res.render('index', {
      title: '¡Plop! - Lo nuevo',
      templates: templates,
      sid: req.sessionID
    });
  });

  app.get("/templates/:template", function(req, res) {
    return templates.send(req.params.template, res);
  });

  app.get("/errbit/test", function(req, res) {
    process.reportError(new Error('My Test Error'));
    return res.send(200);
  });

  app.get("/r/:shortCode", function(req, res) {
    return Post.findOne({
      shortCode: req.params.shortCode
    }).populate('creator').exec(function(err, doc) {
      if (err || !doc) {
        if (err) process.reportError(err);
        return res.send(404);
      } else {
        return res.render('index', {
          post: doc,
          templates: templates,
          sid: req.sessionID
        });
      }
    });
  });

  io.sockets.on('connection', function(socket) {
    return new SocketApp(socket, sessionStore);
  });

}).call(this);
