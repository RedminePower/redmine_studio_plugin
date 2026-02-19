# frozen_string_literal: true

class ReviewSettingAssignment < ActiveRecord::Base
  belongs_to :setting, class_name: 'ReviewSetting', foreign_key: 'setting_id'
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
      user_id: user_id,
      assigned_on: assigned_on,
      assigned_by_id: assigned_by_id
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
