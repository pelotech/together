@Together = {}
@Together.Model =
  Backbone.Model
      
@Together.Collection =
  Backbone.Collection.extend
    model: Together.Model
    initialize: (models, options)->
      socket = io.connect("http://localhost/Together#{@url}")
      socket.on 'reset',(data) =>
        @reset(data)