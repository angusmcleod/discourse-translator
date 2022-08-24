# frozen_string_literal: true

require_relative 'base'
require 'json'

module DiscourseTranslator
  class Google < Base
    TRANSLATE_URI = "https://www.googleapis.com/language/translate/v2".freeze
    DETECT_URI = "https://www.googleapis.com/language/translate/v2/detect".freeze
    SUPPORT_URI = "https://www.googleapis.com/language/translate/v2/languages".freeze
    MAXLENGTH = 5000

    # Hash which maps Discourse's locale code to Google Translate's locale code found in
    # https://cloud.google.com/translate/docs/languages
    SUPPORTED_LANG_MAPPING = {
      en: 'en',
      en_GB: 'en',
      en_US: 'en',
      ar: 'ar',
      bg: 'bg',
      bs_BA: 'bs',
      ca: 'ca',
      cs: 'cs',
      da: 'da',
      de: 'de',
      el: 'el',
      es: 'es',
      et: 'et',
      fi: 'fi',
      fr: 'fr',
      hu: 'hu',
      he: 'iw',
      id: 'id',
      it: 'it',
      ja: 'ja',
      ka: 'ka',
      ko: 'ko',
      lv: 'lv',
      mk: 'mk',
      nl: 'nl',
      pt: 'pt',
      ro: 'ro',
      ru: 'ru',
      sk: 'sk',
      sl: 'sl',
      sq: 'sq',
      sr: 'sr',
      sv: 'sv',
      te: 'te',
      th: 'th',
      uk: 'uk',
      zh_CN: 'zh-CN',
      zh_TW: 'zh-TW',
      tr_TR: 'tr',
      pt_BR: 'pt',
      pl_PL: 'pl',
      no_NO: 'no',
      nb_NO: 'no',
      fa_IR: 'fa'
    }

    def self.access_token_key
      "google-translator"
    end

    def self.access_token
      SiteSetting.translator_google_api_key || (raise TranslatorError.new("NotFound: Google Api Key not set."))
    end

    def self.detect(object)
      object.custom_fields[get_custom_field(object)] ||=
        result(DETECT_URI,
          q: get_text(object, MAXLENGTH)
        )["detections"][0].max { |a, b| a.confidence <=> b.confidence }["language"]
    end

    def self.translate_supported?(source, target)
      res = result(SUPPORT_URI, target: SUPPORTED_LANG_MAPPING[target.to_sym])
      res["languages"].any? { |obj| obj["language"] == source }
    end

    def self.translate(object, target_language = I18n.locale)
      detected_lang = detect(object)

      raise I18n.t('translator.failed') unless translate_supported?(detected_lang, target_language)

      translated_text = from_custom_fields(object, target_language) do
        res = result(TRANSLATE_URI,
          q: get_text(object, MAXLENGTH),
          source: detected_lang,
          target: SUPPORTED_LANG_MAPPING[target_language.to_sym]
        )
        res["translations"][0]["translatedText"]
      end

      [detected_lang, translated_text]
    end

    def self.result(url, body)
      body[:key] = access_token

      response = Excon.post(url,
        body: URI.encode_www_form(body),
        headers: { "Content-Type" => "application/x-www-form-urlencoded" }
      )

      body = nil
      begin
        body = JSON.parse(response.body)
      rescue JSON::ParserError
      end

      if response.status != 200
        raise TranslatorError.new(body || response.inspect)
      else
        body["data"]
      end
    end
  end
end
