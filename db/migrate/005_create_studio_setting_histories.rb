# frozen_string_literal: true

class CreateStudioSettingHistories < ActiveRecord::Migration[6.1]
  def change
    create_table :studio_setting_histories do |t|
      t.integer :studio_setting_id, null: false
      t.string :name, null: false
      t.string :schema_type, null: false
      t.string :scope_type, null: false
      t.integer :scope_id
      t.text :payload
      t.integer :schema_version, null: false
      t.integer :version, null: false
      t.string :change_type, null: false
      t.integer :restored_from_version
      t.string :comment
      t.boolean :is_current, null: false, default: false
      t.datetime :changed_on, null: false
      t.integer :changed_by_id, null: false
    end

    add_index :studio_setting_histories, :studio_setting_id
    add_index :studio_setting_histories, [:studio_setting_id, :version], unique: true
    add_foreign_key :studio_setting_histories, :studio_settings,
                    column: :studio_setting_id, on_delete: :cascade
  end
end
