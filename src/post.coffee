mongoose = require 'mongoose'
async    = require 'async'
request  = require 'request'
url      = require 'url'
Schema   = mongoose.Schema
Util     = require '../lib/util'
User     = require('../lib/user').model
Vote     = require '../lib/vote'
ObjectId = Schema.ObjectId
BSON     = require('mongoose/node_modules/mongodb/lib/mongodb').BSONPure

imageHost = 'plop.s3.amazonaws.com'

schema = new Schema
  images:       { type: {} }
  score:        { type: Number,   index: true }
  title:        { type: String,   required: true }
  creator:      { type: ObjectId, ref: 'User', required: true, index: true }  
  assemblyUrl:  { type: String }
  voters:       [ Vote.schema ]
  votes:        { type: Number,   default: 0, required: true }  
  random:       { type: Number,   default: Math.random, required: true, index: true }
  shortCode:    { type: String,   default: (-> Util::randomString 6), required: true, index: { unique: true } }

# This uses the native mongodb driver implementation.
# Switch to a Mongoose implementation once it becomes available
schema.statics.upvote = (user, shortCode, callback) ->
  userId = new BSON.ObjectID(user.id)
  query = 
    shortCode: shortCode,
    'voters.user': 
      $nin: [ userId ]

  update = 
    $inc: 
      votes: 1
    $push:
      voters: 
        _id: new BSON.ObjectID()
        user: userId

  options =  new: true

  async.waterfall [
    (next) =>
      this.collection.findAndModify query, [], update, options, (err, doc) ->
        unless err or doc
          callback null, null
        else
          next err, doc
    (doc, next) =>
      this.update { _id: doc._id }, 
        $set:
          score: Util::calculateScore doc._id.getTimestamp(), doc.votes
        (err, numAffected) =>
          next err, numAffected
          # We don't pass karma increment errors to the main callback
          if !err and numAffected > 0
            User.incrementKarma doc.creator
  ], callback

schema.statics.random = (callback) ->
  rand = Math.random()
  async.waterfall [
    (next) =>
      this.findOne(random: { $gte: rand }).populate('creator').exec next
    (doc, next) =>
      if doc
        callback null, doc
      else 
        this.findOne(random: { $lte: rand }).populate('creator').exec next
  ], callback

# Get the URL of the image
schema.pre 'save', (next) ->
  return next() unless this.isNew
  request.get this.assemblyUrl, (err, res, assembly) =>
    if err
      next err
    else
      this.images = Util::parseAssembly assembly
      this.markModified 'images'      
      next()

# Add a vote from the creator
schema.pre 'save', (next) ->
  return next() unless this.isNew
  this.voters.push user: this.creator
  this.votes = 1
  this.score = Util::calculateScore this.createdAt(), this.votes
  next()

schema.path('title').validate (v) -> 
  100 > v.length > 3

schema.methods.imageUrl = (size) ->
  "http://#{imageHost}/#{this.images[size]}"

schema.methods.asJson = (obj = {}) ->
  creator = if obj.creator then obj.creator else this.creator
  creator = creator.asJson() if creator.asJson 

  id: this.shortCode
  title: this.title
  images: this.images
  votes: this.votes
  score: this.score
  createdAt: this.createdAt().toISOString()
  creator: creator

schema.methods.createdAt = ->
  this._id.getTimestamp()

schema.methods.toJson = (obj) ->
  JSON.stringify this.asJson(obj)

module.exports.schema = schema
module.exports.model  = mongoose.model 'Post', schema