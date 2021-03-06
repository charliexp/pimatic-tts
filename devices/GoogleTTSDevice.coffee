module.exports = (env) ->
  
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  t = env.require('decl-api').types
  Promise = env.require 'bluebird'
  googleAPI = require('google-tts-api')
  request = require('request')
  lame = require('lame')
  fs = require('fs')
  TTSDevice = require("./TTSDevice")(env)
  
  class GoogleTTSDevice extends TTSDevice
    
    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      
      @actions = _.cloneDeep @actions
      @attributes = _.cloneDeep @attributes
      
      @actions.getSpeed = {
        description: "Returns the Voice speed"
        returns:
          speed:
            type: t.number}
      
      @attributes.speed = {
        description: "Voice speed"
        type: t.number
        acronym: 'Voice Speed:'
        discrete: true}
        
      @_options = {
        speed: @config.speed ? 100
        audioDecoder: lame.Decoder
        audioFormat: 'mp3'
        maxStringLenght: 200
      }

      super()
    
    getSpeed: -> Promise.resolve(@_options.speed)
    
    generateResource: (file) =>
      
      return new Promise( (resolve, reject) =>
        @base.rejectWithErrorString Promise.reject, __("%s: A maximum of 200 characters is allowed.", @id, @_data.text.parsed.length) unless @_data.text.parsed.length < @_options.maxStringLenght
        
        googleAPI(@_data.text.parsed, @_options.language, @_options.speed/100).then( (resource) =>
        
          fsWrite = fs.createWriteStream(file)
            .on('finish', () =>
              fsWrite.close( () => 
                      
                env.logger.info __("%s: Speech resource for '%s' successfully generated.", @id, @_data.text.parsed)
                resolve file
              )
            )
            .on('error', (error) =>
              fs.unlink(file)
              @base.rejectWithErrorString Promise.reject, error
            )
                
          resRead = request.get(resource)
            .on('error', (error) =>
              msg = __("%s: Failure reading audio resource '%s'. Error: %s", @id, resource, error)
              env.logger.debug msg
              @base.rejectWithErrorString Promise.reject, msg
            )
          resRead.pipe(fsWrite)
              
        ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
      ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
    
    destroy: () ->
      super()
  
  return GoogleTTSDevice