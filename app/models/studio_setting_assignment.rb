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
