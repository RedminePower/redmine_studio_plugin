# frozen_string_literal: true

module RedmineStudioPlugin
  module WikiLists
    # マクロのエラーを、本体と同じ形（flash error の枠）で、行を分けて出す。
    # 本体は、マクロが raise したエラー文を文字として出すので、文の中の改行の印（<br>）がそのまま見えてしまう。
    # そこで、エラー文を改行の印・改行で行に分け、各行は文字として出し、行の間だけ改行にする
    module MacroError
      module_function

      def html(view, name, message)
        lines = String.new(message.to_s).split(%r{<br\s*/?>|\n}).map(&:strip).reject(&:empty?)
        error = view.safe_join(lines, view.tag.br)
        text = ::I18n.t(:error_can_not_execute_macro_html, name: ::ERB::Util.h(name.to_s), error: error)
        view.content_tag(:div, text.html_safe, class: 'flash error')
      end
    end
  end
end
