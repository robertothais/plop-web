(function() {
  var BSON, ObjectId, Schema, User, Util, Vote, async, imageHost, mongoose, request, schema, url;

  mongoose = require('mongoose');

  async = require('async');

  request = require('request');

  url = require('url');

  Schema = mongoose.Schema;

  Util = require('../lib/util');

  User = require('../lib/user').model;

  Vote = require('../lib/vote');

  ObjectId = Schema.ObjectId;

  BSON = require('mongoose/node_modules/mongodb/lib/mongodb').BSONPure;

  imageHost = 'plop.s3.amazonaws.com';

  schema = new Schema({
    images: {
      type: {}
    },
    score: {
      type: Number,
      index: true
    },
    title: {
      type: String,
      required: true
    },
    creator: {
      type: ObjectId,
      ref: 'User',
      required: true,
      index: true
    },
    assemblyUrl: {
      type: String
    },
    voters: [Vote.schema],
    votes: {
      type: Number,
      "default": 0,
      required: true
    },
    random: {
      type: Number,
      "default": Math.random,
      required: true,
      index: true
    },
    shortCode: {
      type: String,
      "default": (function() {
        return Util.prototype.randomString(6);
      }),
      required: true,
      index: {
        unique: true
      }
    }
  });

  schema.statics.upvote = function(user, shortCode, callback) {
    var options, query, update, userId,
      _this = this;
    userId = new BSON.ObjectID(user.id);
    query = {
      shortCode: shortCode,
      'voters.user': {
        $nin: [userId]
      }
    };
    update = {
      $inc: {
        votes: 1
      },
      $push: {
        voters: {
          _id: new BSON.ObjectID(),
          user: userId
        }
      }
    };
    options = {
      "new": true
    };
    return async.waterfall([
      function(next) {
        return _this.collection.findAndModify(query, [], update, options, function(err, doc) {
          if (!(err || doc)) {
            return callback(null, null);
          } else {
            return next(err, doc);
          }
        });
      }, function(doc, next) {
        return _this.update({
          _id: doc._id
        }, {
          $set: {
            score: Util.prototype.calculateScore(doc._id.getTimestamp(), doc.votes)
          }
        }, function(err, numAffected) {
          next(err, numAffected);
          if (!err && numAffected > 0) return User.incrementKarma(doc.creator);
        });
      }
    ], callback);
  };

  schema.statics.random = function(callback) {
    var rand,
      _this = this;
    rand = Math.random();
    return async.waterfall([
      function(next) {
        return _this.findOne({
          random: {
            $gte: rand
          }
        }).populate('creator').exec(next);
      }, function(doc, next) {
        if (doc) {
          return callback(null, doc);
        } else {
          return _this.findOne({
            random: {
              $lte: rand
            }
          }).populate('creator').exec(next);
        }
      }
    ], callback);
  };

  schema.pre('save', function(next) {
    var _this = this;
    if (!this.isNew) return next();
    return request.get(this.assemblyUrl, function(err, res, assembly) {
      if (err) {
        return next(err);
      } else {
        _this.images = Util.prototype.parseAssembly(assembly);
        _this.markModified('images');
        return next();
      }
    });
  });

  schema.pre('save', function(next) {
    if (!this.isNew) return next();
    this.voters.push({
      user: this.creator
    });
    this.votes = 1;
    this.score = Util.prototype.calculateScore(this.createdAt(), this.votes);
    return next();
  });

  schema.path('title').validate(function(v) {
    var _ref;
    return (100 > (_ref = v.length) && _ref > 3);
  });

  schema.methods.imageUrl = function(size) {
    return "http://" + imageHost + "/" + this.images[size];
  };

  schema.methods.asJson = function(obj) {
    var creator;
    if (obj == null) obj = {};
    creator = obj.creator ? obj.creator : this.creator;
    if (creator.asJson) creator = creator.asJson();
    return {
      id: this.shortCode,
      title: this.title,
      images: this.images,
      votes: this.votes,
      score: this.score,
      createdAt: this.createdAt().toISOString(),
      creator: creator
    };
  };

  schema.methods.createdAt = function() {
    return this._id.getTimestamp();
  };

  schema.methods.toJson = function(obj) {
    return JSON.stringify(this.asJson(obj));
  };

  module.exports.schema = schema;

  module.exports.model = mongoose.model('Post', schema);

}).call(this);
