# frozen_string_literal: true

module RedmineStudioPlugin
  module WikiLists
    # マクロの書き方の誤り（オプション・値・列の名前など）。利用者に直してもらう誤りだけに使う
    class MacroArgumentError < StandardError; end

    # マクロのエラーを、本体と同じ形（flash error の枠）で、行を分けて出す。
    # 本体は、マクロが raise したエラー文を文字として出すので、文の中の改行の印（<br>）がそのまま見えてしまう。
    # そこで、エラー文を改行の印・改行で行に分け、各行は文字として出し、行の間だけ改行にする
    module MacroError
      module_function

      # 書き方の誤り（MacroArgumentError）は「parameter error:」を頭に付け、使い方（usage）があれば添える。
      # そのほかの思わぬエラーは、本体のマクロのエラーと同じく文だけを出し、
      # どこで起きたか（サーバーの中のファイルの場所）は見ている人に出さずにログへ残す
      def html(view, name, error, usage = nil)
        if error.is_a?(MacroArgumentError)
          message = "parameter error: #{error.message}"
          message += "<br>#{usage}" if usage
        else
          Rails.logger.error("#{name} macro: #{error.class}: #{error.message}\n#{Array(error.backtrace).join("\n")}")
          message = error.message
        end

        lines = String.new(message.to_s).split(%r{<br\s*/?>|\n}).map(&:strip).reject(&:empty?)
        text = ::I18n.t(:error_can_not_execute_macro_html, name: ::ERB::Util.h(name.to_s), error: view.safe_join(lines, view.tag.br))
        view.content_tag(:div, text.html_safe, class: 'flash error')
      end

      # エラーに添える名前の一覧を、5 個ずつ行に分けて並べる
      def name_lines(names)
        names.each_slice(5).collect {|slice| slice.join(', ')}.join(',<br>')
      end
    end
  end
end
