# frozen_string_literal: true

class StudioSetting < ActiveRecord::Base
  belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id'
  belongs_to :updated_by, class_name: 'User', foreign_key: 'updated_by_id'
  belongs_to :deleted_by, class_name: 'User', foreign_key: 'deleted_by_id', optional: true

  has_many :assignments, class_name: 'StudioSettingAssignment', foreign_key: 'setting_id', dependent: :destroy
  has_many :histories, class_name: 'StudioSettingHistory', dependent: :destroy

  # 本人の設定（1 人に 1 種類 1 つ・持ち主は scope_id の利用者）
  SCOPE_USER = 'user'
  SCOPE_TYPES = ['global', 'project', SCOPE_USER].freeze

  validates :name, presence: true
  validates :schema_type, presence: true
  validates :scope_type, presence: true
  # 大文字小文字の違う値（'USER' など）を通すと、本人の設定の守りが効かないレコードになるので、決まった値だけを受ける
  validates :scope_type, inclusion: { in: SCOPE_TYPES }, allow_blank: true
  validates :schema_version, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :scope_id, presence: true, if: :user_scope?
  # 検証の前に重複を見つける（作成の API ではコントローラーが今ある設定を 409 で返す）。
  # 確かめた直後に別の端末が作った場合は、データベースの重複禁止の索引（schema_type, owner_id）で止まる
  validates :schema_type, uniqueness: { scope: :owner_id }, if: :user_scope?
  validate :owner_must_be_user, on: :create, if: :user_scope?
  validate :user_scope_immutable, on: :update

  scope :not_deleted, -> { where(deleted_on: nil) }
  scope :deleted, -> { where.not(deleted_on: nil) }

  # global・user は全ログインユーザーに可視。project は当該プロジェクトのメンバーのみ。admin は全件。
  scope :visible, ->(user = User.current) {
    next all if user&.admin?

    project_ids = user ? user.projects.pluck(:id) : []
    # 空配列は IN (-1) にして無マッチにする（.or の構造互換問題を避けるため SQL 文字列で組む）
    where("scope_type IN (?) OR (scope_type = ? AND scope_id IN (?))",
          ['global', SCOPE_USER], 'project', project_ids.presence || [-1])
  }

  before_validation :sync_owner_id
  before_create :set_timestamps
  before_update :update_timestamps
  before_update :increment_version

  def deleted?
    deleted_on.present?
  end

  def user_scope?
    scope_type == SCOPE_USER
  end

  def visible?(user = User.current)
    return true if user&.admin?
    return true if scope_type == 'global'
    return user.present? && user.logged? if user_scope?

    scope_type == 'project' && scope_id.present? && user&.member_of?(Project.find_by(id: scope_id))
  end

  # 書き換え（更新・削除・割り当て・履歴の操作）ができるか。
  # 本人の設定は本人と管理者だけ。ほかの範囲は従来どおり見える人なら書ける。
  def editable?(user = User.current)
    return user.present? && user.logged? && (user.admin? || scope_id == user.id) if user_scope?

    visible?(user)
  end

  # 持ち主と種類で本人の設定を引く（削除済みも含む）
  def self.find_user_setting(owner_id, schema_type)
    find_by(scope_type: SCOPE_USER, owner_id: owner_id, schema_type: schema_type)
  end

  # 行を押さえてから書く（同時の更新と版の数がぶつからないように）。履歴も同じ取引の中で作る
  def soft_delete(user, comment: nil)
    saved = false
    with_lock do
      self.deleted_on = Time.current
      self.deleted_by = user
      saved = save
      create_history('delete', user, comment: comment) if saved
    end
    saved
  end

  # Create a history record
  # @param change_type [String] 'create', 'update', 'delete', 'undelete', 'restore'
  # @param user [User] The user who made the change
  # @param comment [String, nil] Optional comment
  # @param restored_from_version [Integer, nil] Version number when restoring
  def create_history(change_type, user, comment: nil, restored_from_version: nil)
    # 本人の設定は自動保存で頻繁に書かれるので、履歴を残さない
    return if user_scope?

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

    saved = false
    # 行を押さえてから書く（同時の更新と版の数がぶつからないように）。履歴も同じ取引の中で作る
    with_lock do
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

      saved = save
      create_history(change_type, user, comment: comment, restored_from_version: version) if saved
    end
    saved
  end

  # 履歴の最新の通し番号（設定の version＝書き込みのたびに進む数とは別物）
  def current_history_version
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
      version: version,
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

  # 書き込みが成功するたびに 1 進める（作成時は既定値の 1）
  def increment_version
    self.version = (version || 0) + 1
  end

  # 持ち主の正は scope_id。owner_id は重複禁止の索引（schema_type, owner_id）のための写しで、本人の設定のときだけ持つ。ほかの範囲は NULL
  def sync_owner_id
    self.owner_id = user_scope? ? scope_id : nil
  end

  # 本人の設定の持ち主は、実在する利用者（グループ・匿名は除く）
  def owner_must_be_user
    return if scope_id.blank?

    errors.add(:scope_id, :invalid) unless User.where(id: scope_id, type: 'User').exists?
  end

  # 本人の設定は、範囲・持ち主・種類を変えない。ほかの範囲を本人の設定に変えることもしない
  def user_scope_immutable
    if scope_type_changed? && (scope_type_was == SCOPE_USER || scope_type == SCOPE_USER)
      errors.add(:scope_type, :invalid)
    elsif user_scope? && (scope_id_changed? || schema_type_changed?)
      errors.add(:base, 'scope_id and schema_type of a user setting cannot be changed')
    end
  end
end
