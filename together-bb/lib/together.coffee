Backbone = require('backbone')
redis = require('redis')

exports.listen = (io) ->
  Together = {}

  R = redis.createClient()
  R.on 'error', (err) ->
    console.log "Error:#{err}"
  
  Together.Model =
    Backbone.Model.extend
      sync: (method, model, options) ->
        return false unless method in ['create','read','update','delete']    
        sync[method] @collection.url, model, options.success, (error) ->
          console.log "ERROR:#{error}"
          options.error(error)
      
      authorized: ->
        return @
  
  Together.Collection =
    Backbone.Collection.extend
      model: Together.Model
      initialize: ->
        ions = io.of("/Together#{@url}")
        @bind 'all', (eventName, data) =>
          if eventName.indexOf(':') is -1
            ions.sockets.emit? eventName, data
        ions.on 'connection', (socket) =>
          console.log socket
          socket.emit 'reset', @
        @fetch()
        
      sync: (method, model, options) ->        
        switch
          when 'read'
            console.log "DEBUG: #{method} called on #{@url} collection"
            sync.reads @url, model, options, options.success, options.error
          else
            console.log "DEBUG: #{method} called on Rooms but was not handled"

  Together.CloseDb = ->
    console.log "DEBUG: Closing Redis Connection"
    R.quit()


  sync = 
    create: (key, model, success, error) ->
      return false unless model.get('id')?
      R.hexists key, model.get('id'), (err, result) ->
        return error err if err?
        return error 'id already exists, use update' if result is 1
        R.hset key, model.get('id'), JSON.stringify model
        return success model
      
    read: (key, model, success, error) ->
      return false unless model.get('id')?
      R.hget key, model.get('id'), (err, result) ->
        return error err if err?
        return error 'id not found' unless result?
        console.log "got #{result}"
        return success JSON.parse result
      
    update: (key, model, success, error) ->
      return false unless model.get('id')?
      R.hexists key, model.get('id'), (err, result) ->
        return error err if err?
        if result is 0
          console.log  "DEBUG-Redis: #{model.get 'id'} id doesn't' exists, calling create" 
          return sync.create(key, model, success, error)
        R.hset key, model.get('id'), JSON.stringify model
        return success model
      
    delete: (key, model, success, error) ->
      return error false unless model.get('id')?
      R.hdel key, model.get('id'), (err, result) ->
        return error err if err?
        return error "DEBUG-Redis: #{model.get 'id'} id doesn't exist, nothing happened" if result is 0
        return success model
    
    reads: (key, model, options, success, error) ->
      R.hvals key, (err, results) ->
        if err? then return error err 
        console.log results
        unless results? then return error 'no results'
        retVal = []
        retVal.push JSON.parse result for result in results
        return success retVal
        
  return Together