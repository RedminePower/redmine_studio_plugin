# frozen_string_literal: true

module RedmineStudioPlugin
  module JournalsList
    module QueriesHelperPatch
      extend ActiveSupport::Concern

      included do
        alias_method :column_content_without_journals_list, :column_content
        alias_method :column_content, :column_content_with_journals_list
      end

      # column_content をパッチする。
      # value_object が配列を返すと、デフォルトの column_content は
      # 個別に column_value を呼んで ', ' で結合してしまうため、
      # journals_list の場合は独自のレンダリングを行う。
      def column_content_with_journals_list(column, item)
        if column.name == :journals_list
          journals = column.value_object(item)
          render_journals_list(item, journals)
        else
          column_content_without_journals_list(column, item)
        end
      end

      private

      def render_journals_list(issue, journals)
        return '' if journals.blank?

        css_and_js = journals_list_css_and_js

        rows = journals.map do |journal|
          render_journal_rows(issue, journal)
        end

        thead = content_tag(:thead) do
          content_tag(:tr) do
            content_tag(:th, '#', class: 'jl-note jl-sortable', 'data-sort-col': '0', 'data-sort-type': 'num') +
            content_tag(:th, l(:label_journals_list_author), class: 'jl-author jl-sortable', 'data-sort-col': '1', 'data-sort-type': 'text') +
            content_tag(:th, l(:label_journals_list_date), class: 'jl-date jl-sortable', 'data-sort-col': '2', 'data-sort-type': 'text') +
            content_tag(:th, l(:field_status), class: 'jl-status jl-sortable', 'data-sort-col': '3', 'data-sort-type': 'text') +
            content_tag(:th, l(:field_assigned_to), class: 'jl-assigned-to jl-sortable', 'data-sort-col': '4', 'data-sort-type': 'text') +
            content_tag(:th, l(:label_journals_list_notes), class: 'jl-preview jl-sortable', 'data-sort-col': '5', 'data-sort-type': 'text') +
            content_tag(:th, '', class: 'jl-toggle')
          end
        end

        css_and_js + content_tag(:table, thead + content_tag(:tbody, safe_join(rows)), class: 'journals-list')
      end

      def render_journal_rows(issue, journal)
        note_number = journal.instance_variable_get(:@note_number)
        html_id = "journal-#{issue.id}-#{note_number}"

        # ヘッダー行の各セル
        note_link = link_to(note_number.to_s, issue_path(issue, anchor: "note-#{note_number}"))
        author_name = journal.user ? journal.user.name : '?'
        author_link = journal.user ? link_to(author_name, user_path(journal.user)) : '?'
        date_str = format_time(journal.created_on)
        date_sort_key = journal.created_on.strftime('%Y-%m-%d %H:%M:%S')
        status_name = journal.instance_variable_get(:@cumulative_status_name) || ''
        assigned_to_id = journal.instance_variable_get(:@cumulative_assigned_to_id)
        assigned_to_name = journal.instance_variable_get(:@cumulative_assigned_to_name) || ''
        first_line = journal.notes.to_s.split(/\r?\n/).reject(&:blank?).first.to_s.truncate(100)

        # 表示/非表示ボタン（AJAX で展開するため、クリック処理は JavaScript で行う）
        show_label = respond_to?(:sprite_icon) ? sprite_icon('angle-right', l(:button_show)) : l(:button_show)
        hide_label = respond_to?(:sprite_icon) ? sprite_icon('angle-down', l(:button_hide)) : l(:button_hide)

        show_link = content_tag(:a, show_label,
          href: '#',
          id: "#{html_id}-show",
          class: 'icon icon-collapsed collapsible jl-expand-btn',
          'data-journal-id': journal.id,
          'data-target': html_id
        )

        hide_link = content_tag(:a, hide_label,
          href: '#',
          id: "#{html_id}-hide",
          class: 'icon icon-expanded collapsible jl-collapse-btn',
          'data-target': html_id,
          style: 'display:none;'
        )

        # ヘッダー行
        header_row = content_tag(:tr, class: 'journal-header',
          'data-journal-id': journal.id,
          'data-sort-keys': [note_number.to_s, author_name, date_sort_key, status_name, assigned_to_name, first_line].to_json) do
          content_tag(:td, note_link, class: 'jl-note') +
          content_tag(:td, author_link, class: 'jl-author') +
          content_tag(:td, date_str, class: 'jl-date') +
          content_tag(:td, h(status_name), class: 'jl-status') +
          content_tag(:td, assigned_to_id ? link_to(assigned_to_name, user_path(assigned_to_id)) : '', class: 'jl-assigned-to') +
          content_tag(:td, h(first_line), class: 'jl-preview') +
          content_tag(:td, show_link + hide_link, class: 'jl-toggle')
        end

        # 展開時のコンテンツ行（初期状態は空、AJAX で取得）
        content_row = content_tag(:tr, id: html_id, class: 'journal-content', style: 'display:none;') do
          content_tag(:td, '', colspan: 7, class: 'wiki jl-content-cell')
        end

        header_row + content_row
      end

      # CSS と JavaScript はページ内で1回だけ出力する
      def journals_list_css_and_js
        return ''.html_safe if @journals_list_css_rendered
        @journals_list_css_rendered = true

        css = content_tag(:style, <<~CSS.html_safe)
          table.journals-list {
            border-collapse: collapse;
            width: 100%;
          }
          .journals-list .jl-note {
            text-align: right;
            white-space: nowrap;
            padding-right: 4px;
          }
          .journals-list .jl-author {
            white-space: nowrap;
            padding-right: 8px;
          }
          .journals-list .jl-date {
            white-space: nowrap;
            padding-right: 8px;
            color: #888;
          }
          .journals-list .jl-status {
            white-space: nowrap;
            padding-right: 8px;
          }
          .journals-list .jl-assigned-to {
            white-space: nowrap;
            padding-right: 8px;
          }
          .journals-list td.jl-preview {
            width: 100%;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            max-width: 0;
            color: #666;
            text-align: left;
          }
          .journals-list .jl-toggle {
            white-space: nowrap;
          }
          .journals-list .journal-content td {
            text-align: left;
            padding: 4px 0 8px 30px;
            word-break: break-word;
            overflow-wrap: break-word;
          }
          .journals-list td,
          .journals-list th {
            vertical-align: baseline;
          }
          .journals-list th {
            font-weight: normal;
            font-size: 0.9em;
            color: #888;
            text-align: center;
            padding-bottom: 2px;
          }
          .journals-list th.jl-sortable {
            cursor: pointer;
            white-space: nowrap;
            padding-right: 14px;
            position: relative;
          }
          .journals-list th.jl-sortable:hover {
            color: #555;
          }
          .journals-list th.jl-sorted-asc::after,
          .journals-list th.jl-sorted-desc::after {
            content: '';
            position: absolute;
            right: 3px;
            top: 50%;
            width: 5px;
            height: 5px;
            border-left: 2px solid #888;
            border-bottom: 2px solid #888;
          }
          .journals-list th.jl-sorted-asc::after {
            transform: rotate(135deg);
            margin-top: 0px;
          }
          .journals-list th.jl-sorted-desc::after {
            transform: rotate(-45deg);
            margin-top: -3px;
          }
          .journals-list .jl-loading {
            color: #888;
            font-style: italic;
          }
        CSS

        sort_js = content_tag(:script, <<~JS.html_safe)
          $(document).on('click', '.journals-list th.jl-sortable', function(e) {
            e.preventDefault();
            var $th = $(this);
            var $table = $th.closest('table.journals-list');
            var $tbody = $table.children('tbody').first();
            var colIndex = parseInt($th.attr('data-sort-col'));
            var sortType = $th.attr('data-sort-type');

            var currentDir = $th.attr('data-sort-dir') || 'none';
            var newDir = (currentDir === 'asc') ? 'desc' : 'asc';

            $table.find('th.jl-sortable').removeAttr('data-sort-dir')
              .removeClass('jl-sorted-asc jl-sorted-desc');

            $th.attr('data-sort-dir', newDir);
            $th.addClass(newDir === 'asc' ? 'jl-sorted-asc' : 'jl-sorted-desc');

            var pairs = [];
            $tbody.children('tr.journal-header').each(function() {
              var $header = $(this);
              var $content = $header.next('tr.journal-content');
              var keys = JSON.parse($header.attr('data-sort-keys'));
              var sortKey = keys[colIndex];
              pairs.push({ header: $header[0], content: $content[0], key: sortKey });
            });

            $tbody.children('tr').detach();

            pairs.sort(function(a, b) {
              var valA = a.key;
              var valB = b.key;
              if (sortType === 'num') {
                valA = parseInt(valA) || 0;
                valB = parseInt(valB) || 0;
                return (newDir === 'asc') ? valA - valB : valB - valA;
              } else {
                valA = (valA || '').toString().toLowerCase();
                valB = (valB || '').toString().toLowerCase();
                var cmp = valA.localeCompare(valB);
                return (newDir === 'asc') ? cmp : -cmp;
              }
            });

            for (var i = 0; i < pairs.length; i++) {
              $tbody.append(pairs[i].header);
              if (pairs[i].content) { $tbody.append(pairs[i].content); }
            }
          });
        JS

        expand_js = content_tag(:script, <<~JS.html_safe)
          // AJAX による展開/折りたたみ
          (function() {
            // 単一ジャーナルの展開
            function expandJournal($header, callback) {
              var $content = $header.next('tr.journal-content');
              var $cell = $content.find('.jl-content-cell');
              var $showBtn = $header.find('.jl-expand-btn');
              var $hideBtn = $header.find('.jl-collapse-btn');

              // 既にコンテンツがロード済みならそのまま表示
              if ($cell.attr('data-loaded') === 'true') {
                $content.show();
                $showBtn.hide();
                $hideBtn.show();
                if (callback) callback();
                return;
              }

              // ローディング表示
              $cell.html('<span class="jl-loading">Loading...</span>');
              $content.show();
              $showBtn.hide();
              $hideBtn.show();

              var journalId = $header.attr('data-journal-id');
              $.ajax({
                url: '/journals_list/' + journalId,
                method: 'GET',
                success: function(html) {
                  $cell.html(html);
                  $cell.attr('data-loaded', 'true');
                  if (callback) callback();
                },
                error: function(xhr, textStatus) {
                  var info = xhr.status ? xhr.status : '0 ' + textStatus;
                  $cell.html('<span class="jl-loading">Failed to load. (' + info + ')</span>');
                  if (callback) callback();
                }
              });
            }

            // 単一ジャーナルの折りたたみ
            function collapseJournal($header) {
              var $content = $header.next('tr.journal-content');
              var $showBtn = $header.find('.jl-expand-btn');
              var $hideBtn = $header.find('.jl-collapse-btn');
              $content.hide();
              $showBtn.show();
              $hideBtn.hide();
            }

            // コメント行が展開中かどうか
            function isExpanded($header) {
              return $header.next('tr.journal-content').is(':visible');
            }

            // ヘッダー行ダブルクリックで詳細の表示/非表示を切り替え
            $(document).on('dblclick', '.journals-list tr.journal-header', function(e) {
              e.preventDefault();
              var $header = $(this);
              if (isExpanded($header)) {
                collapseJournal($header);
              } else {
                expandJournal($header);
              }
              // ダブルクリックによるテキスト選択を解除
              if (window.getSelection) { window.getSelection().removeAllRanges(); }
            });

            // 「表示」ボタンクリック
            $(document).on('click', '.jl-expand-btn', function(e) {
              e.preventDefault();
              var $header = $(this).closest('tr.journal-header');
              expandJournal($header);
            });

            // 「隠す」ボタンクリック
            $(document).on('click', '.jl-collapse-btn', function(e) {
              e.preventDefault();
              var $header = $(this).closest('tr.journal-header');
              collapseJournal($header);
            });

            // 一括展開（AJAX で一括取得）
            function expandAllJournals($table) {
              var $headers = $table.find('tr.journal-header');
              var needLoad = [];

              // 既にロード済みのものは即座に展開
              $headers.each(function() {
                var $header = $(this);
                var $content = $header.next('tr.journal-content');
                var $cell = $content.find('.jl-content-cell');
                if ($cell.attr('data-loaded') === 'true') {
                  $content.show();
                  $header.find('.jl-expand-btn').hide();
                  $header.find('.jl-collapse-btn').show();
                } else {
                  needLoad.push($header);
                  // ローディング表示
                  $cell.html('<span class="jl-loading">Loading...</span>');
                  $content.show();
                  $header.find('.jl-expand-btn').hide();
                  $header.find('.jl-collapse-btn').show();
                }
              });

              // 未ロードのものを一括取得
              if (needLoad.length > 0) {
                var ids = needLoad.map(function($h) { return $h.attr('data-journal-id'); });
                $.ajax({
                  url: '/journals_list/show_all',
                  method: 'GET',
                  data: { ids: ids },
                  success: function(data) {
                    needLoad.forEach(function($h) {
                      var jid = $h.attr('data-journal-id');
                      var $cell = $h.next('tr.journal-content').find('.jl-content-cell');
                      if (data[jid]) {
                        $cell.html(data[jid]);
                        $cell.attr('data-loaded', 'true');
                      } else {
                        $cell.html('<span class="jl-loading">Not found.</span>');
                      }
                    });
                  },
                  error: function(xhr, textStatus) {
                    var info = xhr.status ? xhr.status : '0 ' + textStatus;
                    needLoad.forEach(function($h) {
                      var $cell = $h.next('tr.journal-content').find('.jl-content-cell');
                      $cell.html('<span class="jl-loading">Failed to load. (' + info + ')</span>');
                    });
                  }
                });
              }
            }

            // 一括折りたたみ
            function collapseAllJournals($table) {
              $table.find('tr.journal-header').each(function() {
                collapseJournal($(this));
              });
            }

            // ----- コンテキストメニュー -----
            var $menu = $('<div id="jl-context-menu"></div>').hide().appendTo('body');
            function hideMenu() { $menu.hide(); }

            // 右クリックイベント
            $(document).on('contextmenu', '.journals-list tr.journal-header, .journals-list tr.journal-content', function(e) {
              e.preventDefault();
              e.stopPropagation();
              if (typeof contextMenuHide === 'function') { contextMenuHide(); }

              var $tr = $(this);
              var $header = $tr.hasClass('journal-header') ? $tr : $tr.prev('tr.journal-header');
              var $table = $header.closest('table.journals-list');
              var expanded = isExpanded($header);

              var html = '<ul>';
              if (expanded) {
                html += '<li><a href="#" class="jl-cm-hide icon icon-expanded">' + #{l(:label_journals_list_hide_detail).to_json} + '</a></li>';
              } else {
                html += '<li><a href="#" class="jl-cm-show icon icon-collapsed">' + #{l(:label_journals_list_show_detail).to_json} + '</a></li>';
              }
              html += '<li class="jl-cm-separator"></li>';
              html += '<li><a href="#" class="jl-cm-show-all">' + #{l(:label_journals_list_show_all).to_json} + '</a></li>';
              html += '<li><a href="#" class="jl-cm-hide-all">' + #{l(:label_journals_list_hide_all).to_json} + '</a></li>';
              html += '</ul>';
              $menu.html(html);

              var x = e.pageX, y = e.pageY;
              $menu.css({ left: x, top: y }).show();
              var menuW = $menu.outerWidth(), menuH = $menu.outerHeight();
              var winW = $(window).width(), winH = $(window).height(), scrollY = $(window).scrollTop();
              if (x + menuW > winW) { x -= menuW; }
              if (y + menuH > scrollY + winH) { y -= menuH; }
              if (x < 0) { x = 1; }
              if (y < 0) { y = 1; }
              $menu.css({ left: x, top: y });

              $menu.data('jl-header', $header);
              $menu.data('jl-table', $table);
            });

            $(document).on('click', '.jl-cm-show', function(e) {
              e.preventDefault();
              expandJournal($menu.data('jl-header'));
              hideMenu();
            });
            $(document).on('click', '.jl-cm-hide', function(e) {
              e.preventDefault();
              collapseJournal($menu.data('jl-header'));
              hideMenu();
            });
            $(document).on('click', '.jl-cm-show-all', function(e) {
              e.preventDefault();
              expandAllJournals($menu.data('jl-table'));
              hideMenu();
            });
            $(document).on('click', '.jl-cm-hide-all', function(e) {
              e.preventDefault();
              collapseAllJournals($menu.data('jl-table'));
              hideMenu();
            });

            $(document).on('click', function(e) {
              if (!$(e.target).closest('#jl-context-menu').length) { hideMenu(); }
            });
            $(document).on('contextmenu', function(e) {
              if (!$(e.target).closest('.journals-list').length) { hideMenu(); }
            });
            $(window).on('scroll', hideMenu);
          })();
        JS

        context_menu_css = content_tag(:style, <<~CSS.html_safe)
          #jl-context-menu {
            position: absolute;
            z-index: 40;
            font-size: 0.9em;
          }
          #jl-context-menu ul {
            list-style: none;
            margin: 0;
            padding: 2px;
            border: 1px solid #aaa;
            background: #fff;
            box-shadow: 2px 2px 4px rgba(0,0,0,0.15);
          }
          #jl-context-menu li {
            margin: 0;
            padding: 0;
            border: 1px solid #fff;
          }
          #jl-context-menu a {
            display: block;
            padding: 2px 8px 2px 26px;
            color: #333;
            text-decoration: none;
            white-space: nowrap;
          }
          #jl-context-menu a.icon {
            background-position: 6px center;
          }
          #jl-context-menu li:hover {
            border: 1px solid #628db6;
            background-color: #eef5fd;
            border-radius: 3px;
          }
          #jl-context-menu a:hover {
            color: #2A5685;
          }
          #jl-context-menu li.jl-cm-separator {
            border-top: 1px solid #ddd;
            margin: 2px 0;
            border-bottom: none;
            border-left: none;
            border-right: none;
          }
        CSS

        css + sort_js + expand_js + context_menu_css
      end
    end
  end
end
