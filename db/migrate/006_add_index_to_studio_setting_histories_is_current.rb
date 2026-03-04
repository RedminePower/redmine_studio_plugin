# frozen_string_literal: true

class AddIndexToStudioSettingHistoriesIsCurrent < ActiveRecord::Migration[6.1]
  def change
    add_index :studio_setting_histories, [:studio_setting_id, :is_current],
              name: 'index_studio_setting_histories_on_setting_id_and_is_current'
  end
end
