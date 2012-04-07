@Together = {}
for key in Object.keys Backbone
  @Together[key] = Backbone[key]

@Together.Model = Backbone.Model.extend
    get: (attribute) ->
      value = Backbone.Model.prototype.get.call(this, attribute)
      if _.isFunction(value)
        return value.call this
      else
        return value
    toJSON: () ->
      self = this
      data = {}
      json = Backbone.Model.prototype.toJSON.call(this)
      _.each json, (value, key) ->
          data[key] = self.get(key)
      return data
      
@Together.Collection = Backbone.Collection.extend
    model: Together.Model
    initialize: (models, options) ->
      socket = io.connect "#{window.location.origin}/Together#{@url}"
      socket.on 'reset', (data) =>
        @reset(data)
