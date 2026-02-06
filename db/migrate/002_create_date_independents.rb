# frozen_string_literal: true

class CreateDateIndependents < ActiveRecord::Migration[5.2]
  EXPECTED_COLUMNS = {
    title:                    { type: :text },
    is_enabled:               { type: :boolean, default: true },
    project_pattern:          { type: :text },
    calculate_status_pattern: { type: :text },
    project_ids:              { type: :text },
    calculate_status_ids:     { type: :text },
  }.freeze

  def up
    if table_exists?(:date_independents)
      # 旧スタンドアロン版 redmine_date_independent からの乗り換え時、
      # カラム不足や型の不一致を補正する
      reconcile_columns
    else
      create_table :date_independents do |t|
        EXPECTED_COLUMNS.each do |name, spec|
          t.column name, spec[:type], **spec.except(:type)
        end
      end
    end
  end

  def down
    drop_table :date_independents if table_exists?(:date_independents)
  end

  private

  def reconcile_columns
    current_columns = ActiveRecord::Base.connection.columns(:date_independents)

    EXPECTED_COLUMNS.each do |name, spec|
      col = current_columns.find { |c| c.name == name.to_s }

      if col.nil?
        add_column :date_independents, name, spec[:type], **spec.except(:type)
      elsif col.type != spec[:type]
        change_column :date_independents, name, spec[:type], **spec.except(:type)
      end
    end
  end
end
