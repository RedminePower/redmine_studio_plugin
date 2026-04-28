# frozen_string_literal: true

class ChangePayloadToLongtext < ActiveRecord::Migration[6.1]
  def up
    change_column :studio_settings, :payload, :text, limit: 4_294_967_295
    change_column :studio_setting_histories, :payload, :text, limit: 4_294_967_295
  end

  def down
    change_column :studio_settings, :payload, :text
    change_column :studio_setting_histories, :payload, :text
  end
end
