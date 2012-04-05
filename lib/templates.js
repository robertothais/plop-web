(function() {
  var Templates, fs, jade, path;

  fs = require('fs');

  path = require('path');

  jade = require('jade');

  Templates = (function() {

    function Templates() {
      this.cache = {};
    }

    Templates.prototype.filename = function(name) {
      return path.join(process.cwd(), 'views', "" + name + ".jade");
    };

    Templates.prototype.readFile = function(name) {
      return fs.readFileSync(this.filename(name));
    };

    Templates.prototype.compile = function(name) {
      var filename;
      filename = this.filename(name);
      return jade.compile(this.readFile(name), {
        filename: filename
      })({
        templates: this
      });
    };

    Templates.prototype.render = function(name) {
      var _base;
      return (_base = this.cache)[name] || (_base[name] = this.compile(name));
    };

    Templates.prototype.send = function(name, res) {
      try {
        return res.send(this.render(name));
      } catch (error) {
        if (error.code === 'ENOENT') {
          return res.send(404);
        } else {
          throw error;
        }
      }
    };

    Templates.prototype.partials = function() {
      var _base;
      return (_base = this.cache).partials || (_base.partials = JSON.stringify({
        login: this.render('login'),
        preview: this.render('preview'),
        post: this.render('post')
      }));
    };

    return Templates;

  })();

  module.exports = new Templates;

}).call(this);
