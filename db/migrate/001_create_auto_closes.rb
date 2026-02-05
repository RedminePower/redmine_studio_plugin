# frozen_string_literal: true

class CreateAutoCloses < ActiveRecord::Migration[5.2]
  EXPECTED_COLUMNS = {
    title:                           { type: :text },
    is_enabled:                      { type: :boolean, default: true },
    project_pattern:                 { type: :text },
    trigger_type:                    { type: :text },
    trigger_tracker:                 { type: :integer },
    trigger_subject_pattern:         { type: :text },
    trigger_status:                  { type: :integer },
    trigger_custom_field:            { type: :integer },
    trigger_custom_field_boolean:    { type: :boolean, default: true },
    action_user:                     { type: :string },
    action_status:                   { type: :integer },
    action_assigned_to:              { type: :integer },
    action_comment:                  { type: :text },
    is_action_comment_parent:        { type: :boolean },
    action_assigned_to_custom_field: { type: :integer },
    project_ids:                     { type: :text },
    max_issues_per_run:              { type: :integer, default: 50 },
  }.freeze

  def up
    if table_exists?(:auto_closes)
      # 旧スタンドアロン版 redmine_auto_close からの乗り換え時、
      # カラム不足や型の不一致を補正する
      reconcile_columns
    else
      create_table :auto_closes do |t|
        EXPECTED_COLUMNS.each do |name, spec|
          t.column name, spec[:type], **spec.except(:type)
        end
      end
    end
  end

  def down
    drop_table :auto_closes if table_exists?(:auto_closes)
  end

  private

  def reconcile_columns
    current_columns = ActiveRecord::Base.connection.columns(:auto_closes)

    EXPECTED_COLUMNS.each do |name, spec|
      col = current_columns.find { |c| c.name == name.to_s }

      if col.nil?
        add_column :auto_closes, name, spec[:type], **spec.except(:type)
      elsif col.type != spec[:type]
        change_column :auto_closes, name, spec[:type], **spec.except(:type)
      end
    end
  end
end
