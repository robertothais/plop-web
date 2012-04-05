mongoose = require 'mongoose'
async    = require 'async'
request  = require 'request'
Schema   = mongoose.Schema
ObjectId = Schema.ObjectId

schema = new Schema
  facebookId:  { type: String, required: true, index: { unique: true } }  
  username:    { type: String, index: { unique: true, sparse: true} }
  karma:       { type: Number, default: 1, required: true }

schema.statics.authenticate = (access_token, callback) ->  
  User = this
  async.waterfall [
    (next) ->
      request "https://graph.facebook.com/me?access_token=#{access_token}", (err, res, body) ->
        if !err && res.statusCode is 200
          next null, JSON.parse(body).id   
        else
          err = new Error("Error when trying to get Facebook user")
          err.type = 'FacebookApiError'
          err.params = JSON.parse(body)
          next err
    (facebookId, next) -> 
      User.findOne { facebookId: facebookId }, (err, user) ->        
        next err, user, facebookId
    (user, facebookId, next) ->
      unless user
        User.create { facebookId: facebookId }, (err, user) ->          
          next err, user
      else
        next null, user

  ], callback

schema.statics.incrementKarma = (id) ->
  this.update { _id: id }
    $inc:
      karma: 1
    (err, numAffected) ->
      if err 
        process.reportError err

schema.statics.setUsername = (user, username, callback) ->
  if !username or username.length > 30 or username.length < 3 or !username.match /^[a-z0-9\-\_]+$/
    callback type: 'validation'
    return
  this.update { _id: user.id }, username: username, callback 

schema.methods.asJson = (obj) ->
  username: this.username

schema.methods.toJson = (obj) ->
  JSON.stringify this.asJson(obj)
  
module.exports.schema = schema
module.exports.model  = mongoose.model 'User', schema

#{"error_code":1,"error_msg":"An unknown error occurred"}