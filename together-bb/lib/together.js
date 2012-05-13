(function() {
  var Backbone, ready, redis, winston,
    __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  Backbone = require('backbone');

  redis = require('redis');

  winston = require('winston');

  ready = true;

  exports.listen = function(io) {
    var R, Together, key, sync, _i, _len, _ref;
    Together = {};
    _ref = Object.keys(Backbone);
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      key = _ref[_i];
      Together[key] = Backbone[key];
    }
    R = redis.createClient();
    R.on('error', function(err) {
      return winston.error("Together.R.on('error'): " + err);
    });
    Together.Model = (function(_super) {

      __extends(Model, _super);

      function Model() {
        Model.__super__.constructor.apply(this, arguments);
      }

      Model.prototype.sync = function(method, model, options) {
        if (method !== 'create' && method !== 'read' && method !== 'update' && method !== 'delete') {
          return false;
        }
        return sync[method](this.collection.url, model, options.success, function(error) {
          winston.error("Together.Model.sync: " + error);
          return options.error(error);
        });
      };

      Model.prototype.authorized = function() {
        return this;
      };

      Model.prototype.get = function(attribute) {
        var value;
        value = Model.__super__.get.apply(this, arguments);
        if (toString.call(value) === '[object Function]') {
          return value.call(this);
        } else {
          return value;
        }
      };

      Model.prototype.toJSON = function() {
        var data, key;
        data = {};
        for (key in Model.__super__.toJSON.apply(this, arguments)) {
          data[key] = this.get(key);
        }
        return data;
      };

      return Model;

    })(Backbone.Model);
    Together.Collection = (function(_super) {

      __extends(Collection, _super);

      Collection.prototype.model = Together.Model;

      function Collection(models, options) {
        var ions,
          _this = this;
        Collection.__super__.constructor.call(this, models, options);
        if (!(((options != null ? options.socket : void 0) != null) && options.socket === false)) {
          ions = io.of("/Together" + this.url);
          ions.on('connection', function(socket) {
            socket.emit('reset', _this);
            socket.on('fetch', function(_arg) {
              var filter, filterParamters;
              filter = _arg.filter, filterParamters = _arg.filterParamters;
              socket.filter = filter;
              return socket.filterParamters = filter;
            });
            return _this.bind('all', function(eventName, data) {
              if (eventName.indexOf(':') === -1) {
                socket.emit(eventName, data);
                return socket.broadcast.emit(eventName, data);
              }
            });
          });
        }
      }

      Collection.prototype.sync = function(method, model, options) {
        switch (false) {
          case !'read':
            winston.verbose("Together.Collection.sync: " + method + " called on " + this.url + " collection");
            return sync.reads(this.url, model, options, options.success, options.error);
          default:
            return winston.verbose("Together.Collection.sync: " + method + " called on " + this.url + " collection but was not handled");
        }
      };

      Collection.prototype.createAll = function(jsonArray, cb) {
        var callback, cbCount, cbIndex, index, processItems,
          _this = this;
        cbCount = jsonArray.length;
        cbIndex = 0;
        winston.info("createAll started with " + cbCount + " items");
        if (!(jsonArray.length > 0)) cb();
        callback = {
          success: function() {
            if (++cbIndex >= cbCount) {
              winston.info("all creates are finished with " + cbCount + " items");
              return cb();
            }
          }
        };
        index = 0;
        processItems = function(items) {
          var item, _results;
          _results = [];
          while (ready && items.length > 0) {
            item = items.pop();
            _results.push(process.nextTick((function() {
              return _this.create(item, callback);
            }), index));
          }
          return _results;
        };
        return processItems(jsonArray);
      };

      Collection.prototype.destroyAll = function(cb) {
        var cbCount, cbIndex, copy,
          _this = this;
        copy = this.models.slice(0);
        cbCount = this.length;
        cbIndex = 0;
        if (!(copy.length > 0)) cb();
        return copy.forEach(function(item) {
          return item.destroy({
            success: function() {
              if (++cbIndex >= cbCount) {
                _this.reset();
                return cb();
              }
            }
          });
        });
      };

      return Collection;

    })(Backbone.Collection);
    Together.CloseDb = function() {
      winston.verbose("Together.CloseDb: closing redis connection");
      return R.quit();
    };
    sync = {
      create: function(key, model, success, error) {
        if (model.get('id') == null) return false;
        return R.hset(key, model.get('id'), JSON.stringify(model), function(err, result) {
          if (err != null) return error(err);
          return success(model);
        });
      },
      read: function(key, model, success, error) {
        if (model.get('id') == null) return false;
        return R.hget(key, model.get('id'), function(err, result) {
          if (err != null) return error(err);
          if (result == null) return error('id not found');
          return success(JSON.parse(result));
        });
      },
      update: function(key, model, success, error) {
        if (model.get('id') == null) return false;
        return ready = R.hset(key, model.get('id'), JSON.stringify(model), function(err, result) {
          if (err != null) return error(err);
          return success(model);
        });
      },
      "delete": function(key, model, success, error) {
        if (model.get('id') == null) return error(false);
        return R.hdel(key, model.get('id'), function(err, result) {
          if (err != null) return error(err);
          if (result === 0) {
            return error("" + (model.get('id')) + " id doesn't exist, nothing happened");
          }
          return success(model);
        });
      },
      reads: function(key, model, options, success, error) {
        return R.hvals(key, function(err, results) {
          var result, retVal, _j, _len2;
          if (err != null) return error(err);
          if (results == null) return error('no results');
          retVal = [];
          for (_j = 0, _len2 = results.length; _j < _len2; _j++) {
            result = results[_j];
            retVal.push(JSON.parse(result));
          }
          return success(retVal);
        });
      }
    };
    return Together;
  };

}).call(this);
