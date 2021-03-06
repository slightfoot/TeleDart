/**
 * TeleDart - Telegram Bot API for Dart
 * Copyright (C) 2018  Dino PH Leung
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:io' as io;

import 'event/event.dart';
import 'fetch/long_polling.dart';
import 'fetch/webhook.dart';
import '../telegram/telegram.dart';
import '../telegram/model.dart';

class TeleDart {
  final Telegram telegram;
  final Event _event;

  LongPolling _longPolling;
  Webhook _webhook;

  final int maxTimeout = 50;

  /// Constructor in dependency injection manner
  TeleDart(this.telegram, this._event);

  /// Private method to get bot info
  Future<void> _initBotInfo() async {
    await telegram
        .getMe()
        .then((user) => _event.me = user)
        .then((_) => print('${_event.me.username} is initialised'))
        .catchError(
            (exception) => throw new TeleDartException(exception.toString()));
  }

  /// Starts listening to messages
  ///
  /// Use long polling by default.
  ///
  /// Setup desired configurations using [setupLongPolling] or [setupWebhook]
  ///
  /// Throws [TeleDartException]
  Future<void> startFetching({bool webhook: false}) async {
    // initialise bot info before getting updates
    _initBotInfo().then((_) {
      if (webhook) {
        if (_webhook == null)
          throw new TeleDartException('Webhook has not been set up yet');
        else {
          _webhook.startWebhook();
          _webhook.onUpdate().listen((update) => _updatesHandler(update));
        }
      } else {
        _longPolling ??= new LongPolling(telegram);
        _longPolling.startPolling();
        _longPolling.onUpdate().listen((update) => _updatesHandler(update));
      }
    }).catchError(
        ((exception) => throw new TeleDartException(exception.toString())));
  }

  /// Configures long polling method
  ///
  /// See: [https://core.telegram.org/bots/api#getupdates](https://core.telegram.org/bots/api#getupdates)
  void setupLongPolling(
      {int offset: 0,
      int limit: 100,
      int timeout: 30,
      List<String> allowed_updates}) {
    _longPolling = new LongPolling(telegram)
      ..offset = offset
      ..limit = limit
      ..timeout = timeout
      ..allowed_updates = allowed_updates;
  }

  /// Removes and stops long polling
  void removeLongPolling() {
    if (_longPolling != null) _longPolling = null;
  }

  /// Configures webhook method
  ///
  /// Default [port] is `443`, Telegram API supports `443`, `80`, `88`, `8443`.
  /// Provide [privateKey] and [certificate] pair for HTTPS configuration
  ///
  /// See: [https://core.telegram.org/bots/api#setwebhook](https://core.telegram.org/bots/api#setwebhook)
  Future<void> setupWebhook(String url, String secretPath,
      {int port: 443,
      io.File privateKey,
      io.File certificate,
      int max_connections: 40,
      List<String> allowed_updates}) async {
    _webhook = new Webhook(telegram, url, secretPath)
      ..port = port
      ..privateKey = privateKey
      ..certificate = certificate
      ..max_connections = max_connections
      ..allowed_updates = allowed_updates;

    return _webhook.setWebhook();
  }

  /// Removes and stops webhook
  void removeWebhook() {
    if (_webhook != null)
      _webhook.deleteWebhook().then((_) {
        _webhook.stopWebhook();
        _webhook = null;
      });
  }

  // Private method to add updates into events queue
  void _updatesHandler(Update update) {
    _event.emitUpdate(update);
  }

  /// Listens to message events with [entityType] and [keyword] in text and caption
  ///
  /// entityType include `mention` (@username), `hashtag`, `bot_command`, `url`,
  /// `email`, `bold` (bold text), `italic` (italic text), `code` (monowidth string),
  /// `pre` (monowidth block), `text_link` (for clickable text URLs), `text_mention`
  /// (for users without usernames)
  ///
  /// **Normal message has NO [entityType]**
  ///
  /// Normal message accepts regular expressions as [keyword]
  ///
  /// To listen to `/start`
  ///  ```
  ///  onMessage(entityType: 'bot_command', keyword: 'start').listen((message) =>
  ///    teledart.telegram.sendMessage(message.from.id, 'hello world!'));
  ///  ```
  Stream<Message> onMessage({String entityType, String keyword}) =>
      _event.onMessage(entityType: entityType, keyword: keyword);

  /// Listens to edited message events
  Stream<Message> onEditedMessage() => _event.onEditedMessage();

  /// Listens to channel post events
  Stream<Message> onChannelPost() => _event.onChannelPost();

  /// Listens to edited channel post events
  Stream<Message> onEditedChannelPost() => _event.onEditedChannelPost();

  /// Listens to inline query events
  Stream<InlineQuery> onInlineQuery() => _event.onInlineQuery();

  /// Listens to chosen inline query events
  Stream<ChosenInlineResult> onChosenInlineResult() =>
      _event.onChosenInlineResult();

  /// Listens to callback query events
  Stream<CallbackQuery> onCallbackQuery() => _event.onCallbackQuery();

  /// Listens to shipping query events
  Stream<ShippingQuery> onShippingQuery() => _event.onShippingQuery();

  /// Listens to pre checkout query events
  Stream<PreCheckoutQuery> onPreCheckoutQuery() => _event.onPreCheckoutQuery();

  // Short-cuts revolution

  /// Short-cut for onMessage handling entityType `mention` (@username)
  Stream<Message> onMention([String keyword]) =>
      _event.onMessage(entityType: 'mention', keyword: keyword);

  /// Short-cut for onMessage handling entityType `hashtag`
  Stream<Message> onHashtag([String keyword]) =>
      _event.onMessage(entityType: 'hashtag', keyword: keyword);

  /// Short-cut for onMessage handling entityType `bot_command`
  Stream<Message> onCommand([String keyword]) =>
      _event.onMessage(entityType: 'bot_command', keyword: keyword);

  /// Short-cut for onMessage handling entityType `text_link`
  Stream<Message> onTextLink([String keyword]) =>
      _event.onMessage(entityType: 'text_link', keyword: keyword);

  /// Short-cut for onMessage handling entityType `text_mention`
  Stream<Message> onTextMention([String keyword]) =>
      _event.onMessage(entityType: 'text_mention', keyword: keyword);

  /// Short-cut to reply with a text message
  Future<Message> replyMessage(Message orgMsg, String text,
          {bool withQuote: false,
          String parse_mode,
          bool disable_web_page_preview,
          bool disable_notification,
          ReplyMarkup reply_markup}) =>
      telegram.sendMessage(orgMsg.from.id, text,
          parse_mode: parse_mode,
          disable_web_page_preview: disable_web_page_preview,
          disable_notification: disable_notification,
          reply_to_message_id: withQuote ? orgMsg.message_id : null,
          reply_markup: reply_markup);

  /// Short-cut to reply with a photo message
  Future<Message> replyPhoto(Message orgMsg, photo,
          {bool withQuote: false,
          String caption,
          String parse_mode,
          bool disable_notification,
          ReplyMarkup reply_markup}) =>
      telegram.sendPhoto(orgMsg.from.id, photo,
          caption: caption,
          parse_mode: parse_mode,
          disable_notification: disable_notification,
          reply_to_message_id: withQuote ? orgMsg.message_id : null,
          reply_markup: reply_markup);

  /// Short-cut to reply with a audio message
  Future<Message> replyAudio(Message orgMsg, audio,
          {bool withQuote: false,
          String caption,
          String parse_mode,
          int duration,
          String performer,
          String title,
          bool disable_notification,
          ReplyMarkup reply_markup}) =>
      telegram.sendAudio(orgMsg.from.id, audio,
          caption: caption,
          parse_mode: parse_mode,
          duration: duration,
          performer: performer,
          title: title,
          disable_notification: disable_notification,
          reply_to_message_id: withQuote ? orgMsg.message_id : null,
          reply_markup: reply_markup);

  /// Short-cut to reply with a document message
  Future<Message> replyDocument(Message orgMsg, document,
          {bool withQuote: false,
          String caption,
          String parse_mode,
          bool disable_notification,
          ReplyMarkup reply_markup}) =>
      telegram.sendDocument(orgMsg.from.id, document,
          caption: caption,
          parse_mode: parse_mode,
          disable_notification: disable_notification,
          reply_to_message_id: withQuote ? orgMsg.message_id : null,
          reply_markup: reply_markup);

  /// Short-cut to reply with a video message
  Future<Message> replyVideo(Message orgMsg, video,
          {bool withQuote: false,
          int duration,
          int width,
          int height,
          String caption,
          String parse_mode,
          bool supports_streaming,
          bool disable_notification,
          ReplyMarkup reply_markup}) =>
      telegram.sendVideo(orgMsg.from.id, video,
          duration: duration,
          width: width,
          height: height,
          caption: caption,
          parse_mode: parse_mode,
          supports_streaming: supports_streaming,
          disable_notification: disable_notification,
          reply_to_message_id: withQuote ? orgMsg.message_id : null,
          reply_markup: reply_markup);

  /// Short-cut to reply with a voice message
  Future<Message> replyVoice(Message orgMsg, voice,
          {bool withQuote: false,
          String caption,
          String parse_mode,
          bool disable_notification,
          ReplyMarkup reply_markup}) =>
      telegram.sendVoice(orgMsg.from.id, voice,
          caption: caption,
          parse_mode: parse_mode,
          disable_notification: disable_notification,
          reply_to_message_id: withQuote ? orgMsg.message_id : null,
          reply_markup: reply_markup);

  /// Short-cut to reply with a video note message
  Future<Message> replyVideoNote(Message orgMsg, video_note,
          {bool withQuote: false,
          int duration,
          int length,
          bool disable_notification,
          ReplyMarkup reply_markup}) =>
      telegram.sendVideoNote(orgMsg.from.id, video_note,
          duration: duration,
          length: length,
          disable_notification: disable_notification,
          reply_to_message_id: withQuote ? orgMsg.message_id : null,
          reply_markup: reply_markup);

  /// Short-cut to reply with a media group message
  Future<List<Message>> replyMediaGroup(Message orgMsg, List<InputMedia> media,
          {bool withQuote: false, bool disable_notification}) =>
      telegram.sendMediaGroup(orgMsg.from.id, media,
          disable_notification: disable_notification,
          reply_to_message_id: withQuote ? orgMsg.message_id : null);

  /// Short-cut to reply with a location message
  Future<Message> replyLocation(
          Message orgMsg, double latitude, double longitude,
          {bool withQuote: false,
          int live_period,
          bool disable_notification,
          ReplyMarkup reply_markup}) =>
      telegram.sendLocation(orgMsg.from.id, latitude, longitude,
          live_period: live_period,
          disable_notification: disable_notification,
          reply_to_message_id: withQuote ? orgMsg.message_id : null,
          reply_markup: reply_markup);

  /// Short-cut to edit a live location message
  Future<Message> editLiveLocation(double latitude, double longitude,
          {chat_id,
          int message_id,
          String inline_message_id,
          ReplyMarkup reply_markup}) =>
      telegram.editMessageLiveLocation(latitude, longitude,
          chat_id: chat_id,
          message_id: message_id,
          inline_message_id: inline_message_id,
          reply_markup: reply_markup);

  /// Short-cut to stop a live location message
  Future<Message> stopLiveLocation(
          {chat_id,
          int message_id,
          String inline_message_id,
          ReplyMarkup reply_markup}) =>
      telegram.stopMessageLiveLocation(
          chat_id: chat_id,
          message_id: message_id,
          inline_message_id: inline_message_id,
          reply_markup: reply_markup);

  /// Short-cut to reply with a venue message
  Future<Message> replyVenue(Message orgMsg, double latitude, double longitude,
          String title, String address,
          {bool withQuote: false,
          String foursquare_id,
          bool disable_notification,
          ReplyMarkup reply_markup}) =>
      telegram.sendVenue(orgMsg.from.id, latitude, longitude, title, address,
          foursquare_id: foursquare_id,
          disable_notification: disable_notification,
          reply_to_message_id: withQuote ? orgMsg.message_id : null,
          reply_markup: reply_markup);

  /// Short-cut to reply with a contact message
  Future<Message> replyContact(
          Message orgMsg, String phone_number, String first_name,
          {bool withQuote: false,
          String last_name,
          bool disable_notification,
          ReplyMarkup reply_markup}) =>
      telegram.sendContact(orgMsg.from.id, phone_number, first_name,
          last_name: last_name,
          disable_notification: disable_notification,
          reply_to_message_id: withQuote ? orgMsg.message_id : null,
          reply_markup: reply_markup);

  /// Short-cut to answer inline query
  Future<bool> answerInlineQuery(
          InlineQuery inline_query, List<InlineQueryResult> results,
          {int cache_time,
          bool is_personal,
          String next_offset,
          String switch_pm_text,
          String switch_pm_parameter}) =>
      telegram.answerInlineQuery(inline_query.id, results,
          cache_time: cache_time,
          is_personal: is_personal,
          next_offset: next_offset,
          switch_pm_text: switch_pm_text);
}

class TeleDartException implements Exception {
  String cause;
  TeleDartException(this.cause);
  String toString() => 'TeleDartException: ${cause}';
}
