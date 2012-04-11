@Together = {}
for key in Object.keys Backbone
  @Together[key] = Backbone[key]

class @Together.Model extends Backbone.Model
  get: (attribute) ->
    value = super
    if toString.call(value) is '[object Object]'
      return value.call this
    else
      return value
  toJSON: () ->
    data = {}
    data[key] = @get(key) for key of super
    return data
      
class @Together.Collection extends Backbone.Collection
  model: Together.Model
  constructor: (models, options) ->
    super(models, options)
    socket = io.connect "#{window.location.origin}/Together#{@url}"
    socket.on 'reset', (data) =>
      @reset(data)
    socket.on 'add', (data) =>
      @add(data)