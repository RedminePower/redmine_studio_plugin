# frozen_string_literal: true

module RedmineStudioPlugin
  module WikiLists
    module RefIssues
      Redmine::WikiFormatting::Macros.register do
        desc 'Displays a list of referer issues.'
        macro :ref_issues do |obj, args|
          # 一覧の「説明」列などの中の ref_issues は、何も表示しない（NestingGuard）
          RedmineStudioPlugin::WikiLists::NestingGuard.run(:ref_issues_depth) do
            begin
              parser = RedmineStudioPlugin::WikiLists::RefIssues::Parser.new(obj, args, @project)
            rescue => err
              next RedmineStudioPlugin::WikiLists::MacroError.html(self, :ref_issues, err, RedmineStudioPlugin::WikiLists::RefIssues.usage)
            end

            # ref_issues は一覧などの画面のビュー（self）で動くため、本体 SortHelper や @query を
            # そのまま使うと、ホスト画面と共有の状態（表示中のクエリ @query・並び替えの @sort_criteria・
            # 本体の並び順セッションなど）を書き換えてしまう。同じ画面の CSV 出力などがこれを見るので、
            # 描画に要る分だけ使い、下の ensure で必ず元へ戻す。
            preserved_ivars = [:@query, :@issues, :@sort_criteria, :@sortable_columns, :@sort_default]
            undefined_ivar = Object.new
            saved_ivars = preserved_ivars.each_with_object({}) do |iv, h|
              h[iv] = instance_variable_defined?(iv) ? instance_variable_get(iv) : undefined_ivar
            end
            host_sort_key = ("#{controller_name}_#{action_name}_sort" rescue nil)
            host_sort_had = (host_sort_key ? session.key?(host_sort_key) : false) rescue false
            host_sort_val = host_sort_had ? session[host_sort_key] : nil

            begin
              unless parser.has_search_conditions? # 検索条件がなにもなかったら
                # 検索するキーワードを取得する
                parser.search_words_w << parser.default_words(obj)
              end

              @query = parser.query @project

              extend SortHelper
              extend QueriesHelper
              extend IssuesHelper

              name_lines = RedmineStudioPlugin::WikiLists::MacroError.method(:name_lines)

              # -o はカスタムクエリ（-i / -q）の並び順より優先する
              if parser.sort_criteria
                sortable = @query.sortable_columns.select {|_name, sql| sql}.keys
                parser.sort_criteria.each do |name, _order|
                  unless sortable.include?(name)
                    raise MacroArgumentError, "- can not sort by '#{name}'<br>[SORT]<br>#{name_lines.call(sortable)}"
                  end
                end
                default_sort = parser.sort_criteria
              else
                default_sort = @query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria
              end

              # -g はカスタムクエリのグループ条件より優先する。
              # 件数のみ（-c）・リンクのみ（-l）は見出しを出せないため使わない
              if parser.group_by && !parser.count_flag && !parser.only_link
                groupable = @query.groupable_columns.collect {|column| column.name.to_s}
                unless groupable.include?(parser.group_by)
                  raise MacroArgumentError, "- can not group by '#{parser.group_by}'<br>[GROUP]<br>#{name_lines.call(groupable)}"
                end
                @query.group_by = parser.group_by
              end

              sort_clear
              sort_init(default_sort)
              sort_update(@query.sortable_columns)
              # 列の見出しの並び替えの印はクエリの並び順を見るため、-o のときはクエリにも渡す
              @query.sort_criteria = sort_criteria.to_a if parser.sort_criteria

              # 同じ項目を 2 回指定すると、本体の add_filter は後の 1 つで上書きする。黙って片方が効かなくならないよう、
              # 使った項目を覚えておき、2 回目はエラーにする。
              # カスタムクエリ（-i・-q）の条件は、マクロで同じ項目を指定すれば上書きする（-o・-g と同じく、マクロの指定を優先する）
              claimed_filters = []
              claim_filter = lambda do |field, label|
                raise MacroArgumentError, "- the same filter is specified more than once: #{label}" if claimed_filters.include?(field)
                claimed_filters << field
              end

              # 語が 1 つも無い検索（語を取り出せない場所の既定の検索など）は、条件にしない
              {'subject' => [parser.search_words_s, '-s'],
               'description' => [parser.search_words_d, '-d'],
               'subjectdescription' => [parser.search_words_w, '-w']}.each do |field, (words_list, label)|
                words_list.reject(&:empty?).each do |words|
                  claim_filter.call(field, label)
                  @query.add_filter(field, '~', words)
                end
              end

              named_filters = RedmineStudioPlugin::WikiLists::VisibleLookup::NAMED_FILTERS

              parser.additional_filter.each do |filter_set|
                filter = filter_set[:filter]
                operator = filter_set[:operator]
                values = filter_set[:values]

                if (named = named_filters[filter])
                  unless values.nil?
                    values = values.collect do |value|
                      # 見られない物は、無い物と同じエラーにする
                      tgt_obj = named[:find].call(value, @query.project)
                      raise MacroArgumentError, "- can not resolve '#{value}' in #{named[:label]} " if tgt_obj.nil?
                      tgt_obj.id.to_s
                    end
                  end
                  filter = named[:field]
                end

                claim_filter.call(filter, "-f:#{filter_set[:filter]}")
                values = RedmineStudioPlugin::WikiLists::RefIssues.values_for_core(@query, filter, operator, values, filter_set[:filter])
                res = @query.add_filter(filter, operator, values)

                if res.nil?
                  filter_str = filter_set[:filter] + filter_set[:operator] + Array(filter_set[:values]).join('|')
                  raise MacroArgumentError,
                        "- failed add_filter: #{filter_str}<br>" \
                        "[FILTER]<br>#{name_lines.call(@query.available_filters.keys + named_filters.keys)}<br>" \
                        "[OPERATOR]<br>#{name_lines.call(Query.operators_labels.collect {|k, l| "#{k}:#{l}"})}"
                end
              end

              # 本体は、絞り込みの値が 1 つでも確かめに落ちると、絞り込みを全部外して一覧を作る（Query#statement）。
              # 全部のチケットが正しい結果のように出ないよう、エラーにする
              unless @query.valid?
                raise MacroArgumentError, "- invalid filter: #{@query.errors.full_messages.join(', ')}"
              end

              @query.column_names = parser.columns unless parser.columns.empty?
              total_count = @query.issue_count
              @issues = @query.issues(order: sort_clause, limit: parser.display_limit)

              # 表示は SafeBuffer に足していく（文字列は足すときにエスケープされ、HTML は link_to・textilizable・render が作る物だけになる）
              disp = ActiveSupport::SafeBuffer.new
              limit_notice = lambda do
                if total_count > parser.display_limit && !parser.display_limit_specified
                  disp << content_tag(:p, I18n.t('ref_issues_display_limit_reached', limit: parser.display_limit, total: total_count))
                end
              end

              if parser.zero_flag && @issues.size == 0
                # 何も出さない
              elsif parser.only_text || parser.only_link
                limit_notice.call
                atr = parser.only_text || parser.only_link
                text_of = RedmineStudioPlugin::WikiLists::RefIssues.text_reader(atr, @issues)

                @issues.each do |issue|
                  word = text_of.call(issue)
                  disp << ' ' unless disp.empty?

                  if parser.only_link
                    disp << link_to(word, issue_path(issue))
                  else
                    # CommonMark（Redmine 7.0 以降）は非 UTF-8 文字列を拒否するため、
                    # 数値カラム由来の US-ASCII 文字列を UTF-8 に統一してから整形する
                    disp << textilizable(word.dup.force_encoding('UTF-8'), object: issue)
                  end
                end
              elsif parser.count_flag
                disp << total_count.to_s
              else
                limit_notice.call

                if params[:format] == 'pdf'
                  disp << render(partial: 'issues/list.html', locals: {issues: @issues, query: @query})
                else
                  # 一覧の右クリックメニューの JS・CSS をページの頭に入れる（本体の context_menu。戻り値は無い）
                  context_menu
                  disp << render(partial: 'issues/list', locals: {issues: @issues, query: @query})
                end
              end

              disp
            rescue => err
              RedmineStudioPlugin::WikiLists::MacroError.html(self, :ref_issues, err)
            ensure
              saved_ivars.each do |iv, val|
                if val.equal?(undefined_ivar)
                  remove_instance_variable(iv) if instance_variable_defined?(iv)
                else
                  instance_variable_set(iv, val)
                end
              end
              if host_sort_key
                begin
                  host_sort_had ? (session[host_sort_key] = host_sort_val) : session.delete(host_sort_key)
                rescue
                  # セッションを使えない描画では戻す対象もない
                end
              end
            end
          end
        end
      end

      module_function

      # 引数の書き方の誤りのときに添える使い方
      def usage
        columns = RedmineStudioPlugin::WikiLists::MacroError.name_lines(IssueQuery.available_columns.collect {|a| a.name.to_s} + ['cf_*'])
        <<-TEXT
usage: {{ref_issues([option].., [column]..)}}<br>
[options]<br>
-i=CustomQueryID : specify custom query by id<br>
-q=CustomQueryName : specify custom query by name<br>
-p[=identifier] : restrict project<br>
-s[=WORD[|WORD...]] : search words in subject<br>
-d[=WORD[|WORD...]] : search words in description<br>
-w[=WORD[|WORD...]] : search words in subject and description<br>
-f:FILTER[=WORD[|WORD...]] : additional filter<br>
-f:treated USER START|END : issues USER created or updated in the period<br>
-t[=attribute] : display text<br>
-l[=attribute] : display linked text<br>
-c : count issues<br>
-0 : no display if no issues<br>
-n=NUMBER : display limit (default: #{Parser::DEFAULT_DISPLAY_LIMIT}, max: #{Parser::MAX_DISPLAY_LIMIT})<br>
-o=COLUMN[:desc][|COLUMN[:desc]...] : sort order (max #{Parser::MAX_SORT_COLUMNS} columns)<br>
-g=COLUMN : group by<br>
[columns]<br>
#{columns}
TEXT
      end

      # 本体は、数・日付などの項目では、値を 1 つ（範囲の「><」は 2 つ）しか読まず、残りを黙って捨てる。
      # 数の項目（数・親チケット）は、本体の画面と同じく , でつないだ 1 つの値にして渡す。そのほかは、多すぎる値をエラーにする
      JOINABLE_TYPES = [:integer, :tree].freeze
      SINGLE_VALUE_TYPES = [:float, :date, :date_past, :relation].freeze

      def values_for_core(query, filter, operator, values, label)
        return values if values.nil? || values.size < 2

        type = query.available_filters[filter].try(:[], :type)
        if JOINABLE_TYPES.include?(type) && %w[= ~].include?(operator)
          [values.join(',')]
        elsif (JOINABLE_TYPES + SINGLE_VALUE_TYPES).include?(type) && values.size > (operator == '><' ? 2 : 1)
          raise MacroArgumentError, "- too many values for -f:#{label}: #{values.join('|')}"
        else
          values
        end
      end

      # -t=・-l= に書いた属性の値を、チケットごとに読む関数を返す。
      # 属性は、チケットの属性名（status_id など）か、見ている人が見られるカスタムフィールド（cf_数字か名前）。
      # 見られないカスタムフィールドは、無い物と同じエラーにする。
      # そのチケットにカスタムフィールドの値が無いとき（トラッカー・プロジェクトで使っていないなど）は空にする
      def text_reader(atr, issues)
        sample = issues.first
        return ->(_issue) { '' } unless sample
        return ->(issue) { issue.attributes[atr].to_s } if sample.attributes.has_key?(atr)

        lookup = RedmineStudioPlugin::WikiLists::VisibleLookup
        custom_field = lookup.issue_custom_field(atr)
        unless custom_field
          names = sample.attributes.keys + sample.visible_custom_field_values(User.current).collect {|v| "cf_#{v.custom_field.id}"}
          raise MacroArgumentError, "- unknown attribute: '#{atr}'<br>[ATTRIBUTES]<br>#{RedmineStudioPlugin::WikiLists::MacroError.name_lines(names)}"
        end

        lambda do |issue|
          value = lookup.custom_value(issue, custom_field)
          value ? value.value.to_s : ''
        end
      end
    end
  end
end
