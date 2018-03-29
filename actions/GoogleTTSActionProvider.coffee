module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  TTSActionProvider = require('./TTSActionProvider')(env)
  
  class GoogleTTSActionHandler extends env.actions.ActionHandler
    constructor: (@framework, @config, @input) ->
      env.logger.debug __("TextToSpeechActionHandler::constructor() - @input.text: %s, @input.device: %s", @input.text, @input.device.id)
      @_TTSDevice = @input.device
      super()
      
    setup: () ->
      @dependOnDevice(@input.device)
      super()
    
    executeAction: (simulate) =>
      @framework.variableManager.evaluateStringExpression(@input.text).then( (text) =>
        if simulate
          return __("would convert Text to Speech: \"%s\"", text)
        
        else
          return new Promise( (resolve, reject) =>
            env.logger.debug __("TextToSpeechActionHandler - text: %s", text)
            if text.length > 200
              reject __("'%s' is %s characters. A maximum of 200 characters is allowed.", text, text.length) 
            else
              @_TTSDevice.convertToSpeech(text).then( (result) =>
                env.logger.debug result
                resolve result
              )
          ).catch( (error) =>
            env.logger.error error
            @base.rejectWithErrorString Promise.reject, error
          )
      )
    
    destroy: () ->
      super()
      
  class GoogleTTSActionProvider extends TTSActionProvider
    constructor: (@framework, @config) ->
      @_setProvider({
        deviceClass: "GoogleTTSDevice", 
        actionHandler: GoogleTTSActionHandler
      })
      super()
      
    parseAction: (input, context) =>
      return @_parse(input, context)
  
  return GoogleTTSActionProvider