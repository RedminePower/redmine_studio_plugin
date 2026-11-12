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

  def as_json(options = {})
    result = {
      id: id,
      setting_id: setting_id,
      assigned_on: assigned_on
    }
    # 標準 Redmine API のパターンに合わせて、nil の場合はプロパティを省略
    result[:user] = { id: user.id, name: user.name } if user
    result[:assigned_by] = { id: assigned_by.id, name: assigned_by.name } if assigned_by
    result
  end

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
