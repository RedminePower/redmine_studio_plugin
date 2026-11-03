# frozen_string_literal: true

require 'digest'

# Time Entry Summaries API
#
# 作業時間を「人×作業日×プロジェクト」ごとに要約し、区切りごとの要約値（digest）を返す専用エンドポイント。
# クライアントは手元に持っている区切りの digest と比べ、違う区切りだけ作業時間を取り直す。
#
# 実装方針:
# - 標準の TimelogController を継承。絞り込み（from / to / user_id / project_id など）・
#   見える範囲（TimeEntry.visible・「自分の作業時間だけ」の権限）・Redmine の版の違いは本体の TimeEntryQuery に任せる
# - 要約値は SUM・COUNT・MAX だけで作る（GROUP_CONCAT やハッシュ関数は DB ごとに違うので使わない）
# - 記録の表は持たず、問い合わせのたびに今の作業時間から計算する
class TimeEntrySummariesController < TimelogController
  # 期間の上限（日数）。ミニカレンダーの 42 日が入るようにする
  MAX_DAYS = 62
  # user_id に並べられる人数の上限
  MAX_USERS = 100

  # 追加 API は本体の login_required 設定に関わらず一律ログイン必須にする（匿名アクセス遮断）。
  # user_setup（API キー認証）より後に走らせるため通常の before_action で追加する
  before_action :require_login
  before_action :validate_summary_params, :only => :index

  # 権限判定は本エンドポイント名 (time_entry_summaries) ではなく、標準 timelog の権限
  # (view_time_entries) を流用する。Plugin 独自の権限は新設しない。
  # find_optional_project 経由の authorize_global が params[:controller] を渡してくるため、'timelog' に固定して super を呼ぶ
  def authorize(_ctrl = nil, action = params[:action], global = false)
    super('timelog', action, global)
  end

  # GET /time_entry_summaries.json?from=YYYY-MM-DD&to=YYYY-MM-DD&user_id=1|2|3
  def index
    retrieve_time_entry_query
    # from / to は build_from_params が spent_on の絞り込みに変える。並び順は要らないので base_scope を使う
    scope = @query.base_scope

    t = TimeEntry.table_name
    rows = scope.
      group("#{t}.user_id", "#{t}.spent_on", "#{t}.project_id").
      order("#{t}.user_id", "#{t}.spent_on", "#{t}.project_id").
      pluck(
        Arel.sql("#{t}.user_id"),
        Arel.sql("#{t}.spent_on"),
        Arel.sql("#{t}.project_id"),
        Arel.sql("COUNT(*)"),
        Arel.sql("SUM(#{t}.hours)"),
        Arel.sql("MAX(#{t}.updated_on)"),
        Arel.sql("SUM(COALESCE(#{t}.issue_id, 0))"),
        Arel.sql("SUM(#{t}.activity_id)")
      )

    @summaries = rows.map do |user_id, spent_on, project_id, count, hours, max_updated_on, issue_id_sum, activity_id_sum|
      {
        :user_id => user_id.to_i,
        :spent_on => normalize_date(spent_on),
        :project_id => project_id.to_i,
        :digest => build_digest(count, hours, max_updated_on, issue_id_sum, activity_id_sum)
      }
    end

    respond_to do |format|
      format.api
    end
  end

  private

  # 保存した絞り込み（query_id）は使わない。期間の絞り込みが from / to から外れてしまうため
  def retrieve_time_entry_query
    params.delete(:query_id)
    super
  end

  def validate_summary_params
    errors = []
    from = parse_date(params[:from])
    to = parse_date(params[:to])
    errors << 'from is required (YYYY-MM-DD)' if from.nil?
    errors << 'to is required (YYYY-MM-DD)' if to.nil?
    if from && to
      if to < from
        errors << 'to must be on or after from'
      elsif (to - from).to_i + 1 > MAX_DAYS
        errors << "the period must be #{MAX_DAYS} days or less"
      end
    end
    if params[:user_id].present? && params[:user_id].to_s.split('|').size > MAX_USERS
      errors << "user_id must list #{MAX_USERS} users or less"
    end
    return true if errors.empty?

    render_api_errors(errors)
    false
  end

  def parse_date(value)
    return nil unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

    Date.iso8601(value)
  rescue ArgumentError
    nil
  end

  # DB によって Date / 文字列のどちらでも返るため、YYYY-MM-DD にそろえる
  def normalize_date(value)
    value.respond_to?(:strftime) ? value.strftime('%Y-%m-%d') : value.to_s[0, 10]
  end

  # 要約値。中身はクライアントに意味を持たせない（同じかどうかだけを比べる）
  def build_digest(count, hours, max_updated_on, issue_id_sum, activity_id_sum)
    # 時間の合計は浮動小数の足し方で末尾が揺れないよう、小数第 2 位で丸める
    hours_text = format('%.2f', hours.to_f.round(2))
    parts = [count.to_i, hours_text, normalize_time(max_updated_on), issue_id_sum.to_i, activity_id_sum.to_i]
    Digest::SHA256.hexdigest(parts.join('|'))[0, 32]
  end

  # DB によって Time / 文字列のどちらでも返るため、数字だけの文字列にそろえる。
  # 秒より細かい桁は、DB が持っていれば入る（同じ DB では毎回同じ形になる）
  def normalize_time(value)
    return '' if value.nil?
    return value.utc.strftime('%Y%m%d%H%M%S%6N') if value.respond_to?(:utc)

    value.to_s.gsub(/\D/, '')
  end
end
