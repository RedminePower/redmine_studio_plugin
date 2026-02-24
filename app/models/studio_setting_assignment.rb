# frozen_string_literal: true

class StudioSettingAssignment < ActiveRecord::Base
  belongs_to :setting, class_name: 'StudioSetting', foreign_key: 'setting_id'
  belongs_to :user
  belongs_to :assigned_by, class_name: 'User', foreign_key: 'assigned_by_id'

  validates :setting_id, presence: true
  validates :user_id, presence: true, uniqueness: { scope: :setting_id }
  validates :assigned_by_id, presence: true
  validate :user_must_exist

  before_create :set_assigned_on

  def as_json(options = {})
    {
      id: id,
      setting_id: setting_id,
      user: user ? { id: user.id, name: user.name } : nil,
      assigned_on: assigned_on,
      assigned_by: assigned_by ? { id: assigned_by.id, name: assigned_by.name } : nil
    }
  end

  private

  def set_assigned_on
    self.assigned_on = Time.current
  end

  def user_must_exist
    return if user_id.blank?

    unless User.exists?(user_id)
      errors.add(:user_id, "does not exist: #{user_id}")
    end
  end
end
