# frozen_string_literal: true

module RedmineStudioPlugin
  module WikiLists
    # マクロが名前でプロジェクト・利用者などを探すときは、ページを見ている人（User.current）が見られる範囲だけで探す。
    # 見られない物は、無い物と同じに扱う（表示の違いから、あるかどうかが分からないように）
    # 受け付ける書き方（識別子・名前・id）は、マクロごとに前と同じにする
    module VisibleLookup
      module_function

      # ref_issues の -p= : 数字なら id、ほかは識別子（本体の Project.find と同じ）
      def project_by_identifier_or_id(key)
        key.to_s =~ /\A\d+\z/ ? Project.visible.find_by(id: key) : Project.visible.find_by(identifier: key)
      end

      # issue_name_link のプロジェクト : 識別子、無ければ名前
      def project_by_identifier_or_name(key)
        Project.visible.find_by(identifier: key) || Project.visible.find_by(name: key)
      end

      # ログイン名で利用者を探す。
      # ロック中の人も、見られるプロジェクトのメンバーなら探せる（ロック中の人が担当・作成したチケットを絞り込めるように）。
      # 本体の絞り込みの選択肢には、管理者でない人にはロック中の人は出ないが、id を書けば本体も絞り込める
      def user_by_login(login)
        User.visible.find_by(login: login) || locked_members.find_by(login: login)
      end

      # ref_issues の -f:treated の人 : まずログイン名で探し、無くて数字だけなら id で探す
      # （数字だけのログイン名も本体では付けられるため、ログイン名を先にする。見られる範囲は user_by_login と同じ）
      def user_by_login_or_id(key)
        user = user_by_login(key)
        return user if user || key.to_s !~ /\A\d+\z/

        User.visible.find_by(id: key) || locked_members.find_by(id: key)
      end

      # 見られるプロジェクトのメンバーのうち、ロック中の人
      def locked_members
        User.member_of(Project.visible.to_a).where(status: User::STATUS_LOCKED)
      end
      private_class_method :locked_members

      # ref_issues の -f: に書いた名前を探す。project はクエリのプロジェクト（無ければ nil）
      def filter_value(filter, value, project)
        case filter
        when 'tracker' then Tracker.visible.find_by(name: value)
        when 'category'
          IssueCategory.joins(:project).where(Project.allowed_to_condition(User.current, :view_issues)).find_by(name: value)
        when 'status' then IssueStatus.find_by(name: value)
        when 'assigned_to', 'author' then user_by_login(value)
        # 本体の絞り込みの選択肢と同じく、プロジェクトがあればそこで使える版（共有された版を含む）から探す
        when 'version' then (project ? project.shared_versions : Version.visible).find_by(name: value)
        when 'project' then Project.visible.find_by(name: value)
        else raise ArgumentError, "unknown filter: #{filter}"
        end
      end
    end
  end
end
