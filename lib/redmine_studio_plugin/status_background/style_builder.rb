# frozen_string_literal: true

module RedmineStudioPlugin
  module StatusBackground
    # 設定から、チケット詳細画面の枠（div.issue）にステータスごとの背景色を当てる CSS を作る
    module StyleBuilder
      DEFAULT_CLOSED_COLOR = '#f2f2f2'
      # 選べる色（文字が読みやすい薄い色だけ）。キーは言語ファイルの status_background_color_<キー>
      PRESET_COLORS = [
        ['gray', '#f2f2f2'],
        ['blue', '#e8f1fb'],
        ['green', '#e9f5e9'],
        ['red', '#fbeaea']
      ].freeze
      NONE = ''
      CUSTOM = 'custom'
      COLOR_FORMAT = /\A#[0-9a-fA-F]{6}\z/
      BORDER_RATIO = 0.88

      module_function

      # 項目が無い（この機能より前に設定を保存した）ときも有効として扱う
      def enabled?(settings)
        value = settings['status_background_enabled']
        value.nil? || value.to_s == 'true'
      end

      # 設定画面の選択肢の値。未設定なら、終了扱いのステータスだけ薄いグレー
      def choice_for(settings, status)
        choice = hash_setting(settings, 'status_background_colors')[status.id.to_s]
        return (status.is_closed? ? DEFAULT_CLOSED_COLOR : NONE) if choice.nil?
        return choice if choice == CUSTOM || PRESET_COLORS.any? { |_, color| color == choice }

        NONE
      end

      def custom_color_for(settings, status)
        color = hash_setting(settings, 'status_background_custom_colors')[status.id.to_s].to_s
        color.match?(COLOR_FORMAT) ? color.downcase : DEFAULT_CLOSED_COLOR
      end

      # ステータスに当てる背景色。変えないときは nil
      def color_for(settings, status)
        choice = choice_for(settings, status)
        return nil if choice == NONE

        choice == CUSTOM ? custom_color_for(settings, status) : choice
      end

      def css(settings, statuses)
        return '' unless enabled?(settings)

        statuses.map do |status|
          color = color_for(settings, status)
          next unless color

          "div.issue.details.status-#{status.id} { background-color: #{color}; border-color: #{border_color(color)}; }"
        end.compact.join("\n")
      end

      # 枠線は背景色を少し暗くした色にする
      def border_color(color)
        '#' + color[1, 6].scan(/../).map { |hex| format('%02x', (hex.hex * BORDER_RATIO).round) }.join
      end

      def hash_setting(settings, key)
        value = settings[key]
        value.respond_to?(:to_h) ? value.to_h.transform_keys(&:to_s) : {}
      end
    end
  end
end
