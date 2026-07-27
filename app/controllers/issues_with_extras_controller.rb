# frozen_string_literal: true

# Issues With Extras API
#
# Redmine 標準の GET /issues.json / /issues/:id.json のレスポンスに、
# 本 Plugin が提供する reply_count / children_count を追加で含めて返す専用エンドポイント。
#
# 実装方針:
# - 標準の IssuesController を継承。index / show の filter・pagination・include= 処理をそのまま流用する
# - 追加分は view (`app/views/issues_with_extras/*.api.rsb`) 側で 2 行追加のみ
# - 標準の IssuesController の view は上書きしないため、他 Plugin と共存可能
class IssuesWithExtrasController < IssuesController
  # 権限判定は本エンドポイント名 (issues_with_extras) ではなく、標準 issues の権限
  # (view_issues) を流用する。Plugin 独自の権限は新設しない。
  #
  # before_action :authorize (show 等) と find_optional_project 経由の authorize_global (index)
  # の両方が params[:controller] を明示的に渡してくるため、引数がどう来ても 'issues' に
  # 固定して super を呼ぶ。
  def authorize(_ctrl = nil, action = params[:action], global = false)
    super('issues', action, global)
  end
end
