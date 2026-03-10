# frozen_string_literal: true

class StudioSetting < ActiveRecord::Base
  belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id'
  belongs_to :updated_by, class_name: 'User', foreign_key: 'updated_by_id'
  belongs_to :deleted_by, class_name: 'User', foreign_key: 'deleted_by_id', optional: true

  has_many :assignments, class_name: 'StudioSettingAssignment', foreign_key: 'setting_id', dependent: :destroy
  has_many :histories, class_name: 'StudioSettingHistory', dependent: :destroy

  validates :name, presence: true
  validates :schema_type, presence: true
  validates :scope_type, presence: true
  validates :schema_version, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :not_deleted, -> { where(deleted_on: nil) }
  scope :deleted, -> { where.not(deleted_on: nil) }

  before_create :set_timestamps
  before_update :update_timestamps

  def deleted?
    deleted_on.present?
  end

  def soft_delete(user, comment: nil)
    self.deleted_on = Time.current
    self.deleted_by = user
    if save
      create_history('delete', user, comment: comment)
      true
    else
      false
    end
  end

  # Create a history record
  # @param change_type [String] 'create', 'update', 'delete', 'undelete', 'restore'
  # @param user [User] The user who made the change
  # @param comment [String, nil] Optional comment
  # @param restored_from_version [Integer, nil] Version number when restoring
  def create_history(change_type, user, comment: nil, restored_from_version: nil)
    self.class.transaction do
      # Mark previous current history as not current
      histories.where(is_current: true).update_all(is_current: false)

      # Calculate next version number
      next_version = (histories.maximum(:version) || 0) + 1

      histories.create!(
        name: name,
        schema_type: schema_type,
        scope_type: scope_type,
        scope_id: scope_id,
        payload: payload,
        schema_version: schema_version,
        version: next_version,
        change_type: change_type,
        restored_from_version: restored_from_version,
        comment: comment,
        is_current: true,
        changed_on: Time.current,
        changed_by: user
      )
    end
  end

  # Restore from a specific history version
  # @param version [Integer] The version to restore from
  # @param user [User] The user who is restoring
  # @param comment [String, nil] Optional comment
  # @return [Boolean] true if successful
  def restore_from_version(version, user, comment: nil)
    history = histories.find_by(version: version)
    return false unless history

    # Determine change_type based on current state
    was_deleted = deleted?
    change_type = was_deleted ? 'undelete' : 'restore'

    # Restore payload and schema_version from history
    # Note: name is NOT restored (user may have customized it)
    self.payload = history.payload
    self.schema_version = history.schema_version
    self.updated_by = user
    self.updated_on = Time.current

    # If was deleted, also clear deletion info
    if was_deleted
      self.deleted_on = nil
      self.deleted_by = nil
    end

    if save
      create_history(change_type, user, comment: comment, restored_from_version: version)
      true
    else
      false
    end
  end

  # Get the current (latest) history version number
  def current_version
    histories.maximum(:version) || 0
  end

  def as_json(options = {})
    result = {
      id: id,
      name: name,
      schema_type: schema_type,
      scope_type: scope_type,
      scope_id: scope_id,
      schema_version: schema_version,
      created_on: created_on,
      updated_on: updated_on,
      deleted_on: deleted_on
    }
    # 標準 Redmine API のパターンに合わせて、nil の場合はプロパティを省略
    result[:created_by] = { id: created_by.id, name: created_by.name } if created_by
    result[:updated_by] = { id: updated_by.id, name: updated_by.name } if updated_by
    result[:deleted_by] = { id: deleted_by.id, name: deleted_by.name } if deleted_by
    result[:payload] = payload if options[:include_payload]
    result[:assignments] = assignments.map(&:as_json) if options[:include_assignments]
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
