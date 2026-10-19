# frozen_string_literal: true

class CreateRoadmapDisplays < ActiveRecord::Migration[6.1]
  def change
    create_table :roadmap_displays do |t|
      t.string :name, null: false
      t.boolean :is_enabled, null: false, default: true
      t.string :project_pattern
      t.integer :position
      t.text :column_names
      t.string :group_by
      t.text :sort_criteria
      t.string :status_scope, null: false, default: 'all'
      t.text :totalable_names
      t.boolean :keep_standard_list, null: false, default: false
      t.timestamps
    end
  end
end
