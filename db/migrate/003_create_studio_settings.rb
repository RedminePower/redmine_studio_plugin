# frozen_string_literal: true

class CreateStudioSettings < ActiveRecord::Migration[6.1]
  def change
    create_table :studio_settings do |t|
      t.string :name, null: false
      t.string :schema_type, null: false
      t.string :scope_type, null: false
      t.integer :scope_id
      t.text :payload
      t.integer :schema_version, null: false, default: 0
      t.datetime :created_on, null: false
      t.integer :created_by_id, null: false
      t.datetime :updated_on, null: false
      t.integer :updated_by_id, null: false
      t.datetime :deleted_on
      t.integer :deleted_by_id
    end

    add_index :studio_settings, [:schema_type, :scope_type, :scope_id]
    add_index :studio_settings, :deleted_on
  end
end
