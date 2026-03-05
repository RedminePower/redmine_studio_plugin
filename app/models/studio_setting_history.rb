# frozen_string_literal: true

class StudioSettingHistory < ActiveRecord::Base
  belongs_to :studio_setting
  belongs_to :changed_by, class_name: 'User'

  validates :name, presence: true
  validates :schema_type, presence: true
  validates :scope_type, presence: true
  validates :schema_version, presence: true
  validates :version, presence: true, uniqueness: { scope: :studio_setting_id }
  validates :change_type, presence: true, inclusion: { in: %w[create update delete undelete restore] }
  validates :changed_on, presence: true
  validates :changed_by_id, presence: true

  scope :ordered, -> { order(version: :desc) }

  # Check if this history can be deleted
  def deletable?
    !is_current
  end
end
