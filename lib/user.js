(function() {
  var ObjectId, Schema, async, mongoose, request, schema;

  mongoose = require('mongoose');

  async = require('async');

  request = require('request');

  Schema = mongoose.Schema;

  ObjectId = Schema.ObjectId;

  schema = new Schema({
    facebookId: {
      type: String,
      required: true,
      index: {
        unique: true
      }
    },
    username: {
      type: String,
      index: {
        unique: true,
        sparse: true
      }
    },
    karma: {
      type: Number,
      "default": 1,
      required: true
    }
  });

  schema.statics.authenticate = function(access_token, callback) {
    var User;
    User = this;
    return async.waterfall([
      function(next) {
        return request("https://graph.facebook.com/me?access_token=" + access_token, function(err, res, body) {
          return next(err, JSON.parse(body).id);
        });
      }, function(facebookId, next) {
        return User.findOne({
          facebookId: facebookId
        }, function(err, user) {
          return next(err, user, facebookId);
        });
      }, function(user, facebookId, next) {
        if (!user) {
          return User.create({
            facebookId: facebookId
          }, function(err, user) {
            return next(err, user);
          });
        } else {
          return next(null, user);
        }
      }
    ], callback);
  };

  schema.statics.incrementKarma = function(id) {
    return this.update({
      _id: id
    }, {
      $inc: {
        karma: 1
      }
    }, function(err, numAffected) {
      if (err) return process.reportError(err);
    });
  };

  schema.statics.setUsername = function(user, username, callback) {
    if (!username || username.length > 30 || username.length < 3 || !username.match(/^[a-z0-9\-\_]+$/)) {
      callback({
        type: 'validation'
      });
      return;
    }
    return this.update({
      _id: user.id
    }, {
      username: username
    }, callback);
  };

  schema.methods.asJson = function(obj) {
    return {
      username: this.username
    };
  };

  schema.methods.toJson = function(obj) {
    return JSON.stringify(this.asJson(obj));
  };

  module.exports.schema = schema;

  module.exports.model = mongoose.model('User', schema);

}).call(this);
