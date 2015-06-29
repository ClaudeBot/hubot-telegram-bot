{Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, TopicMessage} = require 'hubot'

class Telegram extends Adapter
    constructor: ->
        super
        @token = process.env.TELEGRAM_BOT_TOKEN
        @apiURL = "https://api.telegram.org/bot"
        @telegramBot = null
        @offset = 0
        @robot.logger.info "hubot-telegram-bot: Adapter loaded."

    _telegramRequest: (method, params = {}, handler) ->
        @robot.http("#{@apiURL}#{@token}/#{method}")
            .query(params)
            .get() (err, httpRes, body) ->
                if err or httpRes.statusCode isnt 200
                    return @robot.logger.error "hubot-telegram-bot: #{body} (#{err})"
                payload = JSON.parse(body)
                handler payload.result

    _getMe: (handler) ->
        @_telegramRequest "getMe", null, (res) ->
            handler res

    _createUser: (user, chatId) ->
        _userName = user.username or user.first_name + " " + user.last_name
        @robot.brain.userForId user.id, name: _userName, room: chatId

    _processMsg: (msg) ->
        _chatId = msg.message.chat.id
        # Text message
        _text = msg.message.text
        if _text
            _text = @robot.name + " " + _text if _chatId is msg.message.from.id
            user = @_createUser msg.message.from, _chatId
            message = new TextMessage user, _text, msg.message.message_id
        # Enter message
        else if msg.message.new_chat_participant
            user = @_createUser msg.message.new_chat_participant, _chatId
            message = new EnterMessage user, null, msg.message.message_id
        # Leave message
        else if msg.message.left_chat_participant
            user = @_createUser msg.message.left_chat_participant, _chatId
            message = new LeaveMessage user, null, msg.message.message_id
        # Topic change
        else if msg.message.new_chat_title
            user = @_createUser msg.message.from, _chatId
            message = new TopicMessage user, msg.message.new_chat_title, msg.message.message_id

        @receive message
        @offset = msg.update_id

    send: (envelope, strings...) ->
        message =
            chat_id: envelope.room
            text: strings.join "\n"
            #reply_to_message_id: envelope.message.id
        @_telegramRequest "sendMessage", message, (res) ->
            @robot.logger.debug "hubot-telegram-bot: Sent -> #{res}"

    reply: (envelope, strings...) ->
        for str in strings
            @send envelope.user, "#{envelope.user.name}: #{str}"

    run: ->
        unless @token
            @emit "error", new Error "Missing TELEGRAM_BOT_TOKEN in environment."

        @_getMe (res) =>
            @telegramBot = res
            @robot.logger.info "hubot-telegram-bot: Hello, I'm #{res.first_name}!"

        setInterval =>
            @_telegramRequest "getUpdates", offset: @offset + 1, (res) =>
                @_processMsg obj for obj in res
        , 2000

        @robot.logger.info "hubot-telegram-bot: Adapter running."
        @emit "connected"

exports.use = (robot) ->
    new Telegram robot