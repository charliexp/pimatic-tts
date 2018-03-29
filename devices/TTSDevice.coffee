module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  t = env.require('decl-api').types
  commons = require('pimatic-plugin-commons')(env)
  
  class TTSDevice extends env.devices.Device
    attributes:
      language:
        description: "Voice synthesis language"
        type: t.string
        acronym: 'Language:'
        discrete: true
      speed:
        description: "Voice speed"
        type: t.string
        acronym: 'Voice Speed:'
        discrete: true
      latestResource:
        description: "Audio resource with synthesized text"
        type: t.string
        acronym: 'Audio resource:'
        discrete: true
    
    actions:
      getLanguage:
        description: "Returns the Voice synthesis language"
        returns:
          language:
            type: t.string
      getSpeed:
        description: "Returns the Voice speed"
        returns:
          speed:
            type: t.string
      getLatestResource:
        description: "Returns the synthesized audio resource"
        returns:
          resource:
            type: t.string
    
    createSpeechResource: () ->
      throw new Error "Function \"createSpeechResource\" is not implemented!"
    
    outputSpeech: () ->
      throw new Error "Function \"outputSpeech\" is not implemented!"
      
    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      @_options = {
        language: @config.language ? 'en-GB'
        speed: @config.speed ? 100
        volume: @config.volume ? 40
        iterations: @config.repeat ? 1
        interval: @config.interval ? 0
      }
      
      @_latestText = null
      @_latestResource = null
      
      @_repetitions = []
      @base = commons.base @, 'Plugin'
      
      super()
      
    convertToSpeech: (text) =>
      reject __("%s - text: '%s', tts text provided is null or undefined.", @config.id, text) unless text?
      
      return new Promise( (resolve, reject) =>
        @createSpeechResource(text).then( (resource) =>
          @_setLatestText(text)
          @_setLatestResource(resource)
          
          i = 0
          results = []
          playback = =>

            @outputSpeech(resource).then( (result) =>
              results.push result
              i++
              
              if i < @_options.iterations
                setTimeout(playback, @_options.interval*1000)
              
              else
                @emit('state', false)
                Promise.all(results).then( (result) =>
                  resolve __("'%s' was spoken %s times", text, @_options.iterations)
                ).catch(Promise.AggregateError, (error) =>
                  reject __("'%s' was NOT spoken %s times. Error: %s", text, @_options.iterations, error)
                )
            ).catch( (error) =>
              @emit('state', false)
              reject error
            )
          
          @emit('state', true)
          playback()
          
        ).catch( (error) =>
          reject __("Error while converting '%s' to speech: %s", text, error)
        )
      )
      
    getLanguage: -> Promise.resolve(@config.language)
    getSpeed: -> Promise.resolve(@config.speed)
    getVolume: -> Promise.resolve(@config.volume)
    getRepeat: -> Promise.resolve(@config.repeat)
    getInterval: -> Promise.resolve(@config.interval)
    getLatestText: -> Promise.resolve(@_latestText)
    getLatestResource: -> Promise.resolve(@_latestResource)
    
    _setLatestText: (value) ->
      env.logger.debug __("text: %s", value)
      if @_latestText is value then return
      @_latestText = value
      @emit 'latestText', value
      
    _setLatestResource: (value) ->
      env.logger.debug __("TTS resource: %s", value)
      if @_latestResource is value then return
      @_latestResource = value
      @emit 'latestResource', value
    
    destroy: () ->
      @removeAllListeners('active')
      
      super()

  return TTSDevice