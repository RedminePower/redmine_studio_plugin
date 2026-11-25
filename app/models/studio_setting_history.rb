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

  # comment 列（string 型）の長さの上限
  MAX_COMMENT_LENGTH = 255

  # comment として受けられない値なら、その理由を英語の文で返す（受けられる値・無いときは空）
  def self.comment_errors(value)
    return [] if value.nil?
    return ['comment must be a string'] unless value.is_a?(String)
    return ["comment is too long (maximum is #{MAX_COMMENT_LENGTH} characters)"] if value.length > MAX_COMMENT_LENGTH

    []
  end

  # Check if this history can be deleted
  def deletable?
    !is_current
  end
end
