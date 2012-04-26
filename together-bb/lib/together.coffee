Backbone = require 'backbone'
redis = require 'redis'
winston = require 'winston'

exports.listen = (io) ->
  Together = {}
  for key in Object.keys Backbone
    Together[key] = Backbone[key]

  R = redis.createClient()
  R.on 'error', (err) ->
    winston.error "Together.R.on('error'): #{err}"
  
  class Together.Model extends Backbone.Model
    sync: (method, model, options) ->
      return false unless method in ['create','read','update','delete']    
      sync[method] @collection.url, model, options.success, (error) ->
        winston.error "Together.Model.sync: #{error}"
        options.error(error)
    authorized: ->
      return @
    get: (attribute) ->
      value = super
      if toString.call(value) is '[object Function]'
        return value.call this
      else
        return value
    toJSON: () ->
      data = {}
      data[key] = @get(key) for key of super
      return data
  
  class Together.Collection extends Backbone.Collection
    model: Together.Model
    constructor:(models, options) ->
      super(models, options)
      unless options?.socket? and options.socket is false
        ions = io.of("/Together#{@url}")            
        ions.on 'connection', (socket) =>
          socket.emit 'reset', @
          @bind 'all', (eventName, data) ->
            if eventName.indexOf(':') is -1
              socket.emit eventName, data
              socket.broadcast.emit eventName, data
      
    sync: (method, model, options) ->        
      switch
        when 'read'
          winston.verbose "Together.Collection.sync: #{method} called on #{@url} collection"
          sync.reads @url, model, options, options.success, options.error
        else
          winston.verbose "Together.Collection.sync: #{method} called on #{@url} collection but was not handled"
    createAll: (jsonArray, cb) ->
      winston.verbose "Together.Collection.createAll: starting for #{jsonArray.length} items"
      return cb() unless jsonArray.length > 0 
      byId = {}
      for json in jsonArray
        byId[json.id] = JSON.stringify(json)
      
      R.hmset @url, byId, (error, results) =>
        if error?
          winston.warn "Together.Collection.createAll: post-hmset error #{error}"
          return cb error
        for item in jsonArray
          @models.push new @model(item)
        return cb()
    destroyAll: (cb) ->
      return cb() unless @models.length > 0
      args = [@url]
      @models.forEach (item) ->
        args.push item.get('id')
      R.hdel args, (error, result) ->
        if error?
          winston.warn "Together.Collection.destroyAll: post-hdel error #{error}"
          return cb error
        return cb()
  Together.CloseDb = ->
    winston.verbose "Together.CloseDb: closing redis connection"
    R.quit()


  sync = 
    create: (key, model, success, error) ->
      return false unless model.get('id')?
      R.hexists key, model.get('id'), (err, result) ->
        return error err if err?
        return error 'id already exists, use update' if result is 1
        R.hset key, model.get('id'), JSON.stringify(model), (err, result) ->
          return error err if err?
          return success model
      
    read: (key, model, success, error) ->
      return false unless model.get('id')?
      R.hget key, model.get('id'), (err, result) ->
        return error err if err?
        return error 'id not found' unless result?
        return success JSON.parse result
      
    update: (key, model, success, error) ->
      return false unless model.get('id')?
      R.hexists key, model.get('id'), (err, result) ->
        return error err if err?
        if result is 0
          winston.verbose "Together.sync.update: #{model.get 'id'} id doesn't exist, calling create" 
          return sync.create(key, model, success, error)
        R.hset key, model.get('id'), JSON.stringify(model), (err, result) ->
          return error err if err?
          return success model
      
    delete: (key, model, success, error) ->
      return error false unless model.get('id')?
      R.hdel key, model.get('id'), (err, result) ->
        return error err if err?
        return error "#{model.get 'id'} id doesn't exist, nothing happened" if result is 0
        return success model
    
    reads: (key, model, options, success, error) ->
      R.hvals key, (err, results) ->
        if err? then return error err 
        unless results? then return error 'no results'
        retVal = []
        retVal.push JSON.parse result for result in results
        return success retVal
        
  return Together