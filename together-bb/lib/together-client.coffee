Together = {}
Together.Model =
  Backbone.Model.extend
    initialize: (attributes, options) ->
      if attributes?.id?
        @socket = io.connect("http://localhost/Together#{@url()}", {query:"token=#{@collection.token}"})
      
Together.Collection =
  Backbone.Collection.extend
    model: Together.Model
    initialize: (models, options)->
      if(options?.token?)
        console.log "Yay"
        @token = options.token
        socket = io.connect("http://localhost/Together#{@url}", {query:"token=#{@token}"})
      else
        socket = io.connect("http://localhost/Together#{@url}")
      socket.on 'reset',(data) =>
        @reset(data)