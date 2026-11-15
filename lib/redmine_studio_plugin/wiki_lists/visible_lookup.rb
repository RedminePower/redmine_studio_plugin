# frozen_string_literal: true

module RedmineStudioPlugin
  module WikiLists
    # マクロが名前でプロジェクト・利用者などを探すときは、ページを見ている人（User.current）が見られる範囲だけで探す。
    # 見られない物は、無い物と同じに扱う（表示の違いから、あるかどうかが分からないように）
    # 受け付ける書き方（識別子・名前・id）はマクロごとに違うので、関数を分けている
    module VisibleLookup
      module_function

      # ref_issues の -p= : 数字なら id、ほかは識別子（本体の Project.find と同じ）
      def project_by_identifier_or_id(key)
        key.to_s =~ /\A\d+\z/ ? Project.visible.find_by(id: key) : Project.visible.find_by(identifier: key)
      end

      # wiki_list の -p=・ref_issues の -f:project : 名前
      def project_by_name(name)
        Project.visible.find_by(name: name)
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

      # ref_issues の -q= : 名前でカスタムクエリを探す。見られる範囲は -i=（id）と同じく本体の IssueQuery.visible。
      # 全体のクエリと、このプロジェクトのクエリから探し、同じ名前があれば自分のクエリを先にする
      def custom_query_by_name(name, project)
        queries = IssueQuery.visible.where(name: name).where(project_id: [nil, project&.id].uniq)
        queries.where(user_id: User.current.id).order(:id).first || queries.order(:id).first
      end

      # ref_issues の -t=・-l=・[cf_数字] のカスタムフィールド : cf_数字 なら id、ほかは名前
      def issue_custom_field(key)
        key.to_s =~ /\Acf_(\d+)\z/ ? IssueCustomField.visible.find_by(id: $1) : IssueCustomField.visible.find_by(name: key)
      end

      # チケットのカスタムフィールドの値。そのチケットで使っていない（トラッカー・プロジェクトに無い）ときは nil
      def custom_value(issue, custom_field)
        issue.visible_custom_field_values(User.current).detect {|v| v.custom_field.id == custom_field.id}
      end

      # ref_issues の -f: に名前で書ける項目。名前・本体の絞り込みの項目・エラーに出す探し方・探す処理を、ここ 1 か所に書く
      # （find の project はクエリのプロジェクト。無ければ nil）
      NAMED_FILTERS = {
        'tracker' => {field: 'tracker_id', label: 'Tracker.name',
                      find: ->(name, _project) { Tracker.visible.find_by(name: name) }},
        'category' => {field: 'category_id', label: 'IssueCategory.name',
                       find: ->(name, _project) {
                         IssueCategory.joins(:project).where(Project.allowed_to_condition(User.current, :view_issues)).find_by(name: name)
                       }},
        'status' => {field: 'status_id', label: 'IssueStatus.name',
                     find: ->(name, _project) { IssueStatus.find_by(name: name) }},
        'assigned_to' => {field: 'assigned_to_id', label: 'User.login',
                          find: ->(login, _project) { user_by_login(login) }},
        'author' => {field: 'author_id', label: 'User.login',
                     find: ->(login, _project) { user_by_login(login) }},
        # 本体の絞り込みの選択肢と同じく、プロジェクトがあればそこで使える版（共有された版を含む）から探す
        'version' => {field: 'fixed_version_id', label: 'Version.name',
                      find: ->(name, project) { (project ? project.shared_versions : Version.visible).find_by(name: name) }},
        'project' => {field: 'project_id', label: 'Project.name',
                      find: ->(name, _project) { project_by_name(name) }}
      }.freeze
    end
  end
end
