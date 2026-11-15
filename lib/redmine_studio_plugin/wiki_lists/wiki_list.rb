# frozen_string_literal: true

module RedmineStudioPlugin
  module WikiLists
    module WikiList
      Redmine::WikiFormatting::Macros.register do
        desc 'Displays a list of wiki pages with text elements (only inside wiki-pages).'
        macro :wiki_list do |obj, args|
          # 抜き出した文字の中の wiki_list は、何も表示しない（NestingGuard）
          RedmineStudioPlugin::WikiLists::NestingGuard.run(:wiki_list_depth) do
            # 引数をパース
            conds = []
            joins = nil
            table_width = nil
            column_keys = []
            column_names = []
            column_widths = []

            begin
              raise MacroArgumentError, '- no parameters' if args.count.zero?

              # 同じ指定を 2 回書くと、-p は 0 件になり、-w は後の 1 つだけが効くので、2 回目はエラーにする
              claimed_options = []
              args.each do |arg|
                arg.strip!

                if arg =~ /\A\-([^\=]*)(\=.*)?\z/ # オプション表記発見
                  if %w[p w].include?($1)
                    raise MacroArgumentError, "- the same option is specified more than once: -#{$1}" if claimed_options.include?($1)
                    claimed_options << $1
                  end

                  case $1
                    when 'c' # リストアップの対象を子ページに限定する場合
                      raise MacroArgumentError, '- -c can be used only in wiki pages.' unless obj.respond_to?(:page)
                      conds << "parent_id = #{obj.page.id}"
                    when 'p' # リストアップの対象を特定の別プロジェクトのWikiに限定する場合
                      if arg=~/\A[^\=]+\=(.*)\z/ then # プロジェクト名を指定
                        name = $1.strip
                        # 見られないプロジェクトは、無いプロジェクトと同じエラーにする
                        prj = RedmineStudioPlugin::WikiLists::VisibleLookup.project_by_name(name)
                        raise MacroArgumentError, "- project:#{name} is not found." unless prj
                        conds << "project_id = #{prj.id}"
                      else # プロジェクト名の指定が無い場合は当該WIKIのPJに限定
                        conds << "project_id = #{obj.project.id}"
                      end

                      joins = 'INNER JOIN wikis ON wiki_pages.wiki_id = wikis.id'
                    when 'w' # 表の横幅
                      if arg =~ /\A[^\=]+\=(.*)\z/ # 幅を取得
                        table_width = $1.strip
                      end
                    else
                      raise MacroArgumentError, "- unknown option: #{arg}"
                  end
                else # オプションでない場合はカラム指定
                  if arg =~ /\A(.*)\|(.*)\|(.*)\z/ # 抽出キーワードと別にカラム表示名と列幅の指定がある場合
                    column_keys.push($1.strip)
                    column_names.push($2.strip)
                    column_widths.push($3.strip)
                  elsif arg =~ /\A(.*)\|(.*)\z/ # 抽出キーワードと別にカラム表示名の指定がある場合
                    column_keys.push($1.strip)
                    column_names.push($2.strip)
                    column_widths.push(nil)
                  else # カラム表示名の指定が無い場合は抽出キーワードをカラム表示名にする
                    column_keys.push(arg.strip)
                    column_names.push(arg.strip)
                    column_widths.push(nil)
                  end
                end
              end
            rescue => err
              next RedmineStudioPlugin::WikiLists::MacroError.html(self, :wiki_list, err, <<-TEXT)
usage: {{wiki_list([option].., [column]..)}}<br>
[options]<br>
-c : search child pages<br>
-p[=PROJECT NAME] : restrict search pages to the current project or the named project<br>
-w=WIDTH : table width<br>
[columns]<br>
+title[|COLUMN_NAME[|WIDTH]] : show page title<br>
+alias[|COLUMN_NAME[|WIDTH]] : show page aliases<br>
+project[|COLUMN_NAME[|WIDTH]] : show project name<br>
KEYWORD[|COLUMN_NAME[|WIDTH]] : scan KEYWORD and show following words to EOL<br>
KEYWORD\\TERMINATOR[|COLUMN_NAME[|WIDTH]] : scan KEYWORD and show following words to TERMINATOR
TEXT
            end

            if column_keys.count.zero?
              column_names.push 'title'
              column_keys.push '+title'
              column_widths.push nil
            end

            # 表は content_tag・safe_join で組み立てる。文字はエスケープされ、HTML になるのは link_to・textilizable が作る物だけ
            header = content_tag(:tr, safe_join(column_names.zip(column_widths).collect {|name, width| content_tag(:th, name, width: width)}))
            rows = []

            # Wikiページの抽出
            wiki_pages = WikiPage.joins(joins).where(conds.join(' AND '))

            wiki_pages.each do |wiki_page| #---------------- Wikiページ毎の処理
              next unless wiki_page.visible?
              # 1ページに抽出キーワードが複数あった場合に複数行表示するため一旦表示行を配列に記憶する
              lines_by_page = [[]] # 最初は1ページ1行からスタート
              column_num = 0

              column_keys.each do |column_key| #---------------- カラム毎の処理
                case column_key
                  when '+title' # Wikiページ名
                    html =
                        link_to(wiki_page.title,
                                controller: 'wiki', action: 'show',
                                project_id: wiki_page.project, id: wiki_page.title)
                    RedmineStudioPlugin::WikiLists::WikiList.set_lines(lines_by_page, column_num, html)
                  when '+alias' # Wikiページの別名
                    # 本体は、別名の行き先の Wiki を redirects_to_wiki_id で持つ
                    redirects = WikiRedirect.where(redirects_to_wiki_id: wiki_page.wiki_id, redirects_to: wiki_page.title)
                    html = safe_join(redirects.collect(&:title), tag.br)
                    RedmineStudioPlugin::WikiLists::WikiList.set_lines(lines_by_page, column_num, html)
                  when '+project' # Wikiページのプロジェクト名
                    RedmineStudioPlugin::WikiLists::WikiList.set_lines(lines_by_page, column_num, wiki_page.project.to_s)
                  else # それ以外はWikiページの中からキーワードで表示要素を抽出する
                    new_lines = [] # カラムキーワードが抽出される毎にこの変数に表示行を追加する

                    if column_key =~ /\A(.*)\\(.*)\z/
                      keyword = Regexp.escape($1.strip)
                      terminator = Regexp.escape($2.strip)
                      matches = wiki_page.text.scan /#{keyword}[\s\S]*?#{terminator}/ # キーワードから終端文字列までを抽出
                    else
                      keyword = Regexp.escape(column_key)
                      terminator = false
                      matches = wiki_page.text.scan /#{keyword}.*$/ # キーワードから行末までを抽出
                    end

                    matches.each do |match| # 抽出されたキーワード毎の処理
                      # キーワードの後ろの文字列を抽出
                      match =~
                          if terminator
                            /\A#{keyword}([\s\S]*)#{terminator}/
                          else
                            /\A#{keyword}(.*)\z/
                          end

                      if $1
                        html = textilizable($1.strip) # 前後の空白を除いてWiki表記解釈
                        # Wikiページ内のこれまでのカラム処理で生成されたlinesに表示内容を記入
                        RedmineStudioPlugin::WikiLists::WikiList.set_lines(lines_by_page, column_num, html)

                        lines_by_page.each do |line|
                          new_lines.push(line.dup) # 本カラムによって生成される行にコピーを追加
                        end
                      end
                    end

                    if new_lines.length.zero? # キーワードが１つも抽出されていなかったら空文字を入れておく
                      RedmineStudioPlugin::WikiLists::WikiList.set_lines(lines_by_page, column_num, '')
                    else # 抽出があった場合は本カラムで作られた新しい表示行をページ表示行にする
                      lines_by_page=new_lines
                    end
                end # case column_key

                column_num += 1
              end # カラム毎の処理

              # 配列に記憶されたページ内の表示内容を行にする
              lines_by_page.each do |line|
                rows << content_tag(:tr, safe_join(line.collect {|column| content_tag(:td, column)}))
              end
            end # Wikiページ毎の処理

            content_tag(:table, safe_join([header] + rows), width: table_width)
          end
        end
      end

      # 配列の全ての要素配列のcolumn_num番目にstrを書きこむ
      def set_lines(lines, column_num, str)
        lines.each do |line|
          line[column_num] = str
        end
      end

      module_function :set_lines
    end
  end
end
