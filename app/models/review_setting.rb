# frozen_string_literal: true

class ReviewSetting < ActiveRecord::Base
  belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id'
  belongs_to :updated_by, class_name: 'User', foreign_key: 'updated_by_id'
  belongs_to :deleted_by, class_name: 'User', foreign_key: 'deleted_by_id', optional: true

  has_many :assignments, class_name: 'ReviewSettingAssignment', foreign_key: 'setting_id', dependent: :destroy

  validates :name, presence: true
  validates :scope_type, presence: true
  validates :schema_version, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :not_deleted, -> { where(deleted_on: nil) }
  scope :deleted, -> { where.not(deleted_on: nil) }

  before_create :set_timestamps
  before_update :update_timestamps

  def deleted?
    deleted_on.present?
  end

  def soft_delete(user)
    self.deleted_on = Time.current
    self.deleted_by = user
    save
  end

  def as_json(options = {})
    result = {
      id: id,
      name: name,
      scope_type: scope_type,
      scope_id: scope_id,
      schema_version: schema_version,
      created_on: created_on,
      created_by_id: created_by_id,
      updated_on: updated_on,
      updated_by_id: updated_by_id,
      deleted_on: deleted_on,
      deleted_by_id: deleted_by_id
    }
    result[:payload] = payload if options[:include_payload]
    result
  end

  private

  def set_timestamps
    self.created_on = Time.current
    self.updated_on = Time.current
  end

  def update_timestamps
    self.updated_on = Time.current
  end
end
