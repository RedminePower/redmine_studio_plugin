# frozen_string_literal: true

require 'json'

module RedmineStudioPlugin
  module ServerLogs
    # 動いているアプリケーションサーバーの種類・同時に処理できる数と、ログのレベル。
    # どれも取れなければ nil にし、呼ぶ側（/info）を失敗させない。
    module AppServerInfo
      LOG_LEVEL_NAMES = %w[debug info warn error fatal unknown].freeze

      module_function

      # { name: 'puma' など, capacity: 整数 または nil }
      def app_server(env)
        name = server_name(env)
        { name: name, capacity: name == 'puma' ? puma_capacity : nil }
      rescue StandardError
        { name: 'unknown', capacity: nil }
      end

      def log_level
        level = Rails.logger.level
        level.is_a?(Integer) ? LOG_LEVEL_NAMES[level] : level.to_s.downcase.presence
      rescue StandardError
        nil
      end

      # SERVER_SOFTWARE と、そのサーバーで動いているときだけ入る値で決める（gem が読み込まれているだけでは決めない）
      def server_name(env)
        software = env['SERVER_SOFTWARE'].to_s
        return 'puma' if software.match?(/puma/i)
        return 'thin' if software.match?(/thin/i)
        return 'webrick' if software.match?(/webrick/i)
        # Passenger は自分の読み込み役が PhusionPassenger を定義する（Redmine の Gemfile には入らない）。
        # SERVER_SOFTWARE は前に立つ Apache・nginx の名前になるので、定数で見分ける
        return 'passenger' if defined?(::PhusionPassenger)
        return 'unicorn' if defined?(::Unicorn::HttpServer) && env.key?('unicorn.socket')

        'unknown'
      end

      # 設定の値（ワーカーの数 × 最大スレッド数）を優先し、取れなければ Puma.stats から取る
      def puma_capacity
        capacity_from_config || capacity_from_stats
      end

      def capacity_from_config
        return nil unless defined?(::Puma) && ::Puma.respond_to?(:cli_config) && ::Puma.cli_config

        options = ::Puma.cli_config.options
        max_threads = options[:max_threads].to_i
        return nil if max_threads <= 0

        [options[:workers].to_i, 1].max * max_threads
      rescue StandardError
        nil
      end

      def capacity_from_stats
        return nil unless defined?(::Puma) && ::Puma.respond_to?(:stats)

        stats = ::Puma.respond_to?(:stats_hash) ? ::Puma.stats_hash : JSON.parse(::Puma.stats.to_s)
        stats = stats.transform_keys(&:to_s)
        if stats['worker_status'].is_a?(Array)
          threads = stats['worker_status'].sum { |w| (w['last_status'] || w[:last_status] || {}).transform_keys(&:to_s)['max_threads'].to_i }
          threads.positive? ? threads : nil
        else
          max = stats['max_threads'].to_i
          max.positive? ? max : nil
        end
      rescue StandardError
        nil
      end
    end
  end
end
