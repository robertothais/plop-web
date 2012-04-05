mongoose = require 'mongoose'
Schema   = mongoose.Schema
ObjectId = Schema.ObjectId

schema = new Schema
  user:       { type: ObjectId,  required: true, index: true }
  
module.exports.schema = schema
module.exports.model  = mongoose.model 'Vote', schema