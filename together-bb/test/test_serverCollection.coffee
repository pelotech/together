winston = require 'winston'
winston.remove winston.transports.Console
# winston.add winston.transports.Console,
#   colorize: true,
#   level: 'verbose'
#   timestamp: true

chai = require('chai')
chai.Assertion.includeStack = true;
should = chai.should()
express = require 'express'
app = module.exports = express.createServer()
io = require('socket.io').listen(app)
global.Together = require('together').listen(io)
redis = require 'redis'

R = redis.createClient()

describe 'Together.Collection', () ->
  collection = null
  model = Together.Model
  key = 'randomKey'

  beforeEach () ->
    collection = new Together.Collection
    collection.model = model
    collection.url = key
  
  afterEach (done) ->
    R.del key, done
  
  describe '#createAll', () ->
    it 'calls back on a zero-length array', (done) ->
      collection.createAll [], done

    it 'calls back on a array of length 1', (done) ->
      collection.createAll [{id:'something'}], done

    it 'creates one item', (done) ->
      id = 'randomId'
      collection.createAll [{id}], () ->
        R.hget key, id, (error, result) ->
          JSON.parse(result).should.eql {id} 
          collection.models.length.should.equal 1, 'collection.length is 1'
          collection.models[0].get('id').should.eql id
          done()
          
    it 'creates two items', (done) ->
      id1 = 'randomId1'
      id2 = 'randomId2'
      collection.createAll [{id:id1},{id:id2}], () ->
        cbIndex = 0
        cbCount = 2
        internalDone = () ->
          if ++cbIndex >= cbCount
            done()
        collection.models.length.should.equal 2
        R.hget key, id1, (error, result) ->
          JSON.parse(result).should.eql {id:id1} 
          internalDone()
        R.hget key, id2, (error, result) ->
          JSON.parse(result).should.eql {id:id2} 
          internalDone()

  describe '#destroyAll', () ->
    it 'calls back on an empty collection', (done) ->
      collection.destroyAll done
      
    it 'deletes one item', (done) ->
      id = 'randomId'
      collection.create {id}, {success:() ->
        collection.length.should.equal 1
        R.hget key, id, (error, result) ->
          JSON.parse(result).should.eql {id}
          collection.destroyAll () ->
            R.hget key, id, (error, result) ->
              throw "result should be null" if result isnt null
              done()
        }
        
    it 'deletes two items', (done) ->
      id1 = 'randomId1'
      id2 = 'randomId2'
      collection.createAll [{id:id1},{id:id2}], () ->
        collection.models.length.should.equal 2
        R.hkeys key, (error, result) ->
          result.length.should.equal 2
          collection.destroyAll () ->
            R.hkeys key, (error, result) ->
              result.length.should.equal 0
              done()