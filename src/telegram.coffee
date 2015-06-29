{Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, TopicMessage} = require 'hubot'

class Telegram extends Adapter
    constructor: ->
        super
        @token = process.env.TELEGRAM_BOT_TOKEN
        @refreshRate = process.env.TELEGRAM_BOT_REFRESH or 1500
        @webhook = process.env.TELEGRAM_BOT_WEBHOOK or false

        @apiURL = "https://api.telegram.org/bot"

        @telegramBot = null
        @offset = 0

        @robot.logger.info "hubot-telegram-bot: Adapter loaded."

    _telegramRequest: (method, params = {}, handler) ->
        @robot.http("#{@apiURL}#{@token}/#{method}")
            .header("Accept", "application/json")
            .query(params)
            .get() (err, httpRes, body) =>
                if err or httpRes.statusCode isnt 200
                    return @robot.logger.error "hubot-telegram-bot: #{body} (#{err})"
                payload = JSON.parse body
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
        # Privacy mode
        _text = _text.substr(1) if _text.charAt(0) is "/"
        if _text
            # PM
            _text = @robot.name + " " + _text if _chatId is msg.message.from.id
            # Create user
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

        @_telegramRequest "sendMessage", message, (res) =>
            @robot.logger.debug "hubot-telegram-bot: Send -> #{res}"

    reply: (envelope, strings...) ->
        message =
            chat_id: envelope.room
            text: strings.join "\n"
            reply_to_message_id: envelope.message.id

        @_telegramRequest "sendMessage", message, (res) =>
            @robot.logger.debug "hubot-telegram-bot: Reply -> #{res}"

    run: ->
        unless @token
            @emit "error", new Error "You must configure the TELEGRAM_BOT_TOKEN environment variable."

        @_getMe (res) =>
            @telegramBot = res
            @robot.logger.info "hubot-telegram-bot: Hello, I'm #{res.first_name}!"

        if @webhook
            @_telegramRequest "setWebhook", url: @webhook, (res) =>
                @robot.logger.info "hubot-telegram-bot: Using webhook method (`#{@webhook}`) for receiving updates."

            @robot.router.post "/telegram", (httpReq, httpRes) =>
                payload = httpReq.body.result
                @_processMsg obj for obj in payload
        else
            setInterval =>
                @_telegramRequest "getUpdates", offset: @offset + 1, (res) =>
                    @_processMsg obj for obj in res
            , @refreshRate

        @robot.logger.info "hubot-telegram-bot: Adapter running."
        @emit "connected"

exports.use = (robot) ->
    new Telegram robot