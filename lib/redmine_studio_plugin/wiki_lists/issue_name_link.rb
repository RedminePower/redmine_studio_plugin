# frozen_string_literal: true

module RedmineStudioPlugin
  module WikiLists
    module IssueNameLink
      Redmine::WikiFormatting::Macros.register do
        desc 'Make a link of an issue by its subject.'
        macro :issue_name_link do |obj, args|
          begin
            raise MacroArgumentError, '- no parameters' if args.count.zero?
            raise MacroArgumentError, '- too many parameters' if args.count > 1
            arg = args.shift
            arg.strip!

            if arg =~ /\A([^:]*):([^:]*)\z/
              # 見られないプロジェクト・チケットは、無い物と同じ表示にする
              prj = RedmineStudioPlugin::WikiLists::VisibleLookup.project_by_identifier_or_name($1)
              raise MacroArgumentError, "- project:#{$1} is not found." unless prj
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
            raise MacroArgumentError, "- issue:#{name} is not found in prj:#{prj.to_s}" unless issue
            link_to(disp, issue_path(issue))
          rescue => err
            RedmineStudioPlugin::WikiLists::MacroError.html(self, :issue_name_link, err, <<-TEXT)
usage: {{issue_name_link([project:]issue_subject[|text])}}
TEXT
          end
        end
      end
    end
  end
end
