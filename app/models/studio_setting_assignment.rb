# frozen_string_literal: true

class StudioSettingAssignment < ActiveRecord::Base
  belongs_to :setting, class_name: 'StudioSetting', foreign_key: 'setting_id'
  belongs_to :user
  belongs_to :assigned_by, class_name: 'User', foreign_key: 'assigned_by_id'

  validates :setting_id, presence: true
  validates :user_id, presence: true, uniqueness: { scope: :setting_id }
  validates :assigned_by_id, presence: true
  # 割り当てるときだけ確かめる（前からある割り当ては、相手がロックされた・プロジェクトから外れた後も残す）
  validate :user_must_be_assignable, on: :create

  before_create :set_assigned_on

  # 割り当てる。もう割り当て済みなら、何もせず今ある割り当てを返す（同じ依頼を何度送っても同じ結果になるように）。
  # 戻り値は [割り当て, 新しく作ったか]。検証で断られたときは、保存していない割り当て（errors 付き）を返す。
  # 設定の行を押さえてから確かめる（同時の割り当て・置き換えと順に処理する）。
  # 押さえが効かない DB で、確かめてから書くまでの間にほかの依頼が先に書いたときも、今ある割り当てを返す
  def self.assign(setting, user_id, assigned_by)
    assign_locked(setting, user_id, assigned_by)
  rescue ActiveRecord::RecordNotUnique
    # 書く時点で、DB の重複禁止の索引に断られた（取引は巻き戻っているので、外で読み直す）
    [setting.assignments.find_by!(user_id: user_id), false]
  end

  def self.assign_locked(setting, user_id, assigned_by)
    setting.with_lock do
      existing = setting.assignments.find_by(user_id: user_id)
      next [existing, false] if existing

      assignment = new(setting: setting, user_id: user_id, assigned_by: assigned_by)
      next [assignment, true] if assignment.save

      # 検証の間に先に書かれた（重複で断られた）。上と同じ問い合わせなので、覚えておいた「無し」を使わずに読み直す
      if assignment.errors.of_kind?(:user_id, :taken)
        existing = uncached { setting.assignments.find_by(user_id: user_id) }
      end
      existing ? [existing, false] : [assignment, false]
    end
  end
  private_class_method :assign_locked

  # 割り当てを user_ids の人だけに置き換え、置き換えた後の割り当て（user_ids の順）を返す。
  # user_ids に入っている、もう割り当て済みの人は、確かめ直さずにそのまま残す
  # （今の一覧を読んで送り返すと、ロック中の人などがいるだけで全体が断られないように）。
  # 新しく足す人が割り当てられない（検証で断られた）ときは、何も変えずに ActiveRecord::RecordInvalid を上げる。
  # 設定の行を押さえてから読む（同時の置き換え・割り当てで、互いの結果が混ざらないように）。
  # 押さえが効かない DB で、読んでから書くまでの間にほかの依頼が同じ人を先に書いたときは、1 度だけ読み直してやり直す。
  # それでも重複で断られたときは ActiveRecord::RecordNotUnique をそのまま上げる
  def self.replace(setting, user_ids, assigned_by)
    retried = false
    begin
      replace_locked(setting, user_ids, assigned_by)
    rescue ActiveRecord::RecordNotUnique
      raise if retried

      retried = true
      setting.assignments.reset
      retry
    end
  end

  def self.replace_locked(setting, user_ids, assigned_by)
    setting.with_lock do
      # 列と同じ型にそろえて比べる（"5" と 5 を同じ人として扱う）
      user_id_type = type_for_attribute(:user_id)
      requested = user_ids.map { |user_id| user_id_type.cast(user_id) }
      kept, to_remove = setting.assignments.reload.to_a.partition { |a| requested.include?(a.user_id) }
      to_remove.each(&:destroy!)
      kept_by_user = kept.index_by(&:user_id)

      # 新しく足す人だけを作る（同じ人が 2 回あると、2 回目は重複で断る）
      user_ids.map do |user_id|
        kept_by_user.delete(user_id_type.cast(user_id)) ||
          create!(setting: setting, user_id: user_id, assigned_by: assigned_by)
      end
    end
  end
  private_class_method :replace_locked

  private

  def set_assigned_on
    self.assigned_on = Time.current
  end

  # 割り当てられるのは、割り当てる人から見える、有効な利用者（グループ・匿名は除く）。
  # 見えない相手は、いない相手と同じ文で断る（だれがいるかを知らせない）。
  # project の設定は、そのプロジェクトのメンバーにだけ割り当てる（メンバーでない人は開けない。管理者はどれでも開ける）
  def user_must_be_assignable
    return if user_id.blank? || assigned_by.nil?

    # 管理者の場合 User.visible はロック中も含むので、有効で絞る
    target = User.visible(assigned_by).active.where(type: 'User').find_by(id: user_id)
    if target.nil?
      errors.add(:user_id, :user_not_found, id: user_id)
    elsif setting&.project_scope? && !setting.visible?(target)
      errors.add(:user_id, :not_project_member, id: user_id)
    end
  end
end
