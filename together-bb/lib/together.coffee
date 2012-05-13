Backbone = require 'backbone'
redis = require 'redis'
winston = require 'winston'
_ = require 'underscore'

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
    filters: {}
    constructor:(models, options) ->
      super
      unless options?.socket? and options.socket is false
        ions = io.of("/Together#{@url}")            
        ions.on 'connection', (socket) =>
          socket.on 'fetch', (options, cb) =>
            socket.filter = options?.filter
            socket.filterParameters = options?.filterParameters
            tryFilter(socket, 'reset', @)
            return cb()
          @bind 'all', (eventName, data) ->      
            winston.info "Together.Collection: got event #{eventName}"
            if eventName.indexOf(':') is -1
              tryFilter(sock, eventName, data) for sock in ions.sockets
                
                
    tryFilter: (socket, eventName, data) ->
      filter = @filters[socket.filter]
      dataToSend = data
      if _(filter).isFunction()
        dataToSend = filter(data, socket.filterParameters)
      socket.emit eventName, dataToSend
      
    sync: (method, model, options) ->        
      switch
        when 'read'
          winston.verbose "Together.Collection.sync: #{method} called on #{@url} collection"
          sync.reads @url, model, options, options.success, options.error
        else
          winston.warn "Together.Collection.sync: #{method} called on #{@url} collection but was not handled"
    createAll: (jsonArray, cb) ->
      cbCount = jsonArray.length
      cbIndex = 0
      winston.info "createAll started with #{cbCount} items"
      cb() unless jsonArray.length > 0
      callback = 
        success: () ->
          if ++cbIndex >= cbCount
            winston.info "all creates are finished with #{cbCount} items"
            return cb()

      index = 0
      for item in jsonArray
        index++
        do (item) =>
          setTimeout((() => @create(item, callback)), index) 
      winston.info "finished scheduling all creates for #{cbCount} items"

    destroyAll: (cb) ->
      copy = @models.slice(0)
      cbCount = @length
      cbIndex = 0
      cb() unless copy.length > 0
      copy.forEach (item) =>
        item.destroy 
          success: () =>
            if ++cbIndex >= cbCount
              @reset()
              return cb()
  Together.CloseDb = ->
    winston.verbose "Together.CloseDb: closing redis connection"
    R.quit()


  sync = 
    create: (key, model, success, error) ->
      return false unless model.get('id')?
      # R.hexists key, model.get('id'), (err, result) ->
      #   return error err if err?
      #   return error 'id already exists, use update' if result is 1
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
      # R.hexists key, model.get('id'), (err, result) ->
      #   return error err if err?
      #   if result is 0
      #winston.verbose "Together.sync.update: #{model.get 'id'} id doesn't exist, calling create" 
      #     return sync.create(key, model, success, error)
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