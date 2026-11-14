# frozen_string_literal: true

module RedmineStudioPlugin
  module WikiLists
    module IssueNameLink
      Redmine::WikiFormatting::Macros.register do
        desc 'Make a link of a issue by its subject.'
        macro :issue_name_link do |obj, args|
          out = ''

          begin
            raise '- no parameters' if args.count.zero?
            raise '- too many parameters' if args.count > 1
            arg = args.shift
            arg.strip!

            if arg =~ /\A([^:]*):([^:]*)\z/
              # 見られないプロジェクト・チケットは、無い物と同じ表示にする
              prj = RedmineStudioPlugin::WikiLists::VisibleLookup.project_by_identifier_or_name($1)
              raise "- project:#{$1} is not found." unless prj
              arg = $2
            else
              prj = obj.project
            end

            if arg =~ /\A([^\|]*)\|([^\|]*)\z/
              name = $1
              disp = $2
            else
              name = arg
              disp = arg
            end

            issue = Issue.visible.where(project_id: prj.id, subject: name).first
            raise "- issue:#{name} is not found in prj:#{prj.to_s}" unless issue
            out += link_to("#{disp}", issue_path(issue))
          rescue => err_msg
            return RedmineStudioPlugin::WikiLists::MacroError.html(self, :issue_name_link, <<-TEXT)
Parameter error: #{err_msg}<br>
Usage: {{issue_name_link([project_name:]issue_subject[|description])}}
TEXT
          end

          out.html_safe
        end
      end
    end
  end
end
