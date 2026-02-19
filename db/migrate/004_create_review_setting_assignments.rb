# frozen_string_literal: true

class CreateReviewSettingAssignments < ActiveRecord::Migration[6.1]
  def change
    create_table :review_setting_assignments do |t|
      t.integer :setting_id, null: false
      t.integer :user_id, null: false
      t.datetime :assigned_on, null: false
      t.integer :assigned_by_id, null: false
    end

    add_index :review_setting_assignments, :setting_id
    add_index :review_setting_assignments, :user_id
    add_index :review_setting_assignments, [:setting_id, :user_id], unique: true
  end
end
