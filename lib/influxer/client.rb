require 'influxdb'

module Influxer
  # InfluxDB API client
  class Client < ::InfluxDB::Client
    def initialize
      @instrumenter = ActiveSupport::Notifications.instrumenter
      super Influxer.config.database, Influxer.config.as_json.symbolize_keys!
    end

    def cached_query(sql)
      log(sql) do
        if Influxer.config.cache == false
          query(sql)
        else
          Rails.cache.fetch(normalized_cache_key(sql), cache_options(sql)) { query(sql) }
        end
      end
    end

    private

    def log(sql)
      return yield unless logger.debug?

      start_ts = Time.now
      res = yield
      duration = (Time.now - start_ts) * 1000

      name  = "InfluxDB SQL (#{duration.round(1)}ms)"

      # bold black name and blue query string
      msg = "\e[1m\e[30m#{name}\e[0m  \e[34m#{sql}\e[0m"
      logger.debug msg
      res
    end

    # if sql contains 'now()' set expires to 1 minute or :cache_now_for value
    # of config.cache if defined
    def cache_options(sql = nil)
      options = Influxer.config.cache.dup
      options[:expires_in] = (options[:cache_now_for] || 60) if sql =~ /\snow\(\)/
      options
    end

    # add prefix; remove whitespaces
    def normalized_cache_key(sql)
      "influxer:#{sql.gsub(/\s*/, '')}"
    end

    def logger
      Rails.logger
    end
  end
end
