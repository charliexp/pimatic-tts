# The amazing dash-button plugin
module.exports = (env) ->

  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  M = env.matcher
  TTS = require('google-tts-api')
  Player = require('player')
  
  class TextToSpeechPlugin extends env.plugins.Plugin
    
    init: (app, @framework, @config) =>
      @debug = @config.debug || false
      @base = commons.base @, 'Plugin'
      @queue = []
      @player = null
      
      @framework.ruleManager.addActionProvider(new TextToSpeechActionProvider(@framework, @config))
    
    playVoice:(voice) =>
      @player = new Player(voice)
        .on('playend', (item) =>
          return new Promise( (resolve, reject) =>
            @player = null
            msg = __("%s was played", voice)
            env.logger.debug __("Plugin::playVoice::player.on.playend - %s", msg)
            resolve msg
          )
        )

        .on('error', (error) =>
          return new Promise( (resolve, reject) =>
            @player = null
            if 'No next song was found' is error
              msg = __("%s was played", voice)
              env.logger.debug __("Plugin::playVoice::player.on.error - %s", msg)
              resolve msg
            else
              reject error
          )
        )
        .play()
    
    toSpeech: (text, language, speed) =>
      language ?= @config.language
      speed ?= @config.speed
      env.logger.debug __("Plugin::toSpeech - text: %s, language: %s, speed: %s", text, language, speed)
      return new Promise( (resolve, reject) =>
        TTS(text, language, speed/100).then( (url) =>
          resolve url
        ).catch( (err) =>
          reject err
        )
      )
      
  class TextToSpeechActionProvider extends env.actions.ActionProvider
    
    constructor: (@framework, @config) ->
      
    parseAction: (input, context) =>
      retVal = null
      text = {value: null, language: null, speed: null, repetitions: 1, delay: null}
      fullMatch = no

      setString = (m, tokens) => text.value = tokens
      setSpeed = (m, tokens) => text.speed = tokens
      setRepetitions = (m, tokens) => text.repetitions = tokens
      setIntervalTime = (m, tokens) => text.interval = tokens*1000
      setLanguage = (m, tokens) => text.language = tokens
      onEnd = => fullMatch = yes
      
      m = M(input, context)
        .match("Say ")
        .matchStringWithVars(setString)
        .match(" using ")
        .match(["nl-NL", "en-GB"], setLanguage)
        .match(" speed ")
        .matchNumber(setSpeed)
        .match(" repeat ")
        .matchNumber(setRepetitions)
        .match(" interval ")
        .matchNumber(setIntervalTime)
        

      if m.hadMatch()
        match = m.getFullMatch()
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new TextToSpeechActionHandler(@framework, text)
        }
      else
        return null
        
  class TextToSpeechActionHandler extends env.actions.ActionHandler
  
    constructor: (@framework, @text) ->
      env.logger.debug __("TextToSpeechActionHandler::constructor() - @text.value: %s, @text.language: %s", @text.value, @text.language)
    
    executeAction: (simulate) =>
      env.logger.debug __("TextToSpeechActionHandler::executeAction() - @text.value: %s, @text.language: %s", @text.value, @text.language)
      if simulate
        # just return a promise fulfilled with a description about what we would do.
        return __("would convert Text to Speech: \"%s\"", @text.value)
      else
        return new Promise( (resolve, reject) =>
          @framework.variableManager.evaluateStringExpression(@text.value).then( (text) =>
            env.logger.debug __("TextToSpeechActionHandler::@framework.variableManager.evaluateStringExpression: - string: %s, @text.language: %s, speed: %s, repeat: %s, delay: %s", text, @text.language, @text.speed, @text.repetitions, @text.interval)
            Plugin.toSpeech(text, @text.language, @text.speed).then( (url) =>
              repetitions = []
              i = 2
              repetitions.push Plugin.playVoice(url, @text.language, @text.speed)
              interval = setInterval(( =>
                if i <= @text.repetitions
                  repetitions.push Plugin.playVoice(url, @text.language, @text.speed)
                else
                  clearInterval(interval)
                  Promise.all(repetitions).then( (results) =>
                    resolve __("'%s' was spoken %s times", text, @text.repetitions)
                  ).catch(Promise.AggregateError, (err) =>
                    @base.rejectWithErrorString Promise.reject, __("'%s' was NOT spoken %s times", text, @text.repetitions)
                  )
                i++
              ), @text.interval)
            )
          )
        )
  Plugin = new TextToSpeechPlugin
  return Plugin