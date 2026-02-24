# frozen_string_literal: true

class CreateStudioSettingAssignments < ActiveRecord::Migration[6.1]
  def change
    create_table :studio_setting_assignments do |t|
      t.integer :setting_id, null: false
      t.integer :user_id, null: false
      t.datetime :assigned_on, null: false
      t.integer :assigned_by_id, null: false
    end

    add_index :studio_setting_assignments, :setting_id
    add_index :studio_setting_assignments, :user_id
    add_index :studio_setting_assignments, [:setting_id, :user_id], unique: true
  end
end
