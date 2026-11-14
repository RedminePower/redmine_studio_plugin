# frozen_string_literal: true

module RedmineStudioPlugin
  module WikiLists
    # マクロの展開の中で同じマクロがもう一度呼ばれたら、何も表示しない（自分を展開し続けてページが開けなくなるのを防ぐ）。
    # 入れ子になるのはほぼ一覧の中（ref_issues の説明の列・wiki_list の抜き出した文字）で、表の中に表を出しても読めない。
    # 自分を呼んでいるかどうかは見ずに入れ子をすべて止めるため、知らせの文も出さない（毎行に並ぶ雑音になる）
    module NestingGuard
      module_function

      def run(key)
        return ''.html_safe if (Thread.current[key] || 0) > 0

        Thread.current[key] = (Thread.current[key] || 0) + 1
        begin
          yield
        ensure
          Thread.current[key] = [(Thread.current[key] || 0) - 1, 0].max
        end
      end
    end
  end
end
