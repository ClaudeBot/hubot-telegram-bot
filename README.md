# hubot-telegram-bot

A Hubot adapter for Telegram Bots with zero external dependencies.

See [`src/telegram.coffee`](src/telegram.coffee) for full documentation.


## Installation via NPM

```
npm install --save hubot-telegram-bot
```

Now, run Hubot with the `telegram-bot` adapter:

```
./bin/hubot -a telegram-bot
```


## Configuration

Variable | Default | Description
--- | --- | ---
`TELEGRAM_BOT_TOKEN` | N/A | Your bot's authorisation token. You can create one by messaging [_BotFather_](https://telegram.me/botfather) `/newbot` [(Docs)](https://core.telegram.org/bots#botfather)
`TELEGRAM_BOT_REFRESH` | 1500 | The polling interval in seconds (i.e. how often should we fetch new messages from Telegram)
`TELEGRAM_BOT_WEBHOOK` | false | The webhook URL for incoming messages to be published by Telegram
