# frozen_string_literal: true

class AddVersionAndOwnerToStudioSettings < ActiveRecord::Migration[6.1]
  INDEX_NAME = 'index_studio_settings_on_schema_type_and_owner_id'

  def up
    # 保存のたびに 1 ずつ進む版。書き込み時の版確認（expected_version）に使う
    add_column :studio_settings, :version, :integer, null: false, default: 1

    # 本人の設定（scope_type = 'user'）のときだけ持ち主の利用者 ID が入る。ほかの範囲は NULL
    add_column :studio_settings, :owner_id, :integer

    # 前の版でも scope_type = 'user' の行は作れたので、持ち主を写してから索引を張る。
    # 同じ人・同じ種類の行が 2 つ以上あると索引の作成で止まる（どちらを残すかは人が決める）
    execute("UPDATE studio_settings SET owner_id = scope_id WHERE scope_type = 'user'")

    # 1 人に同じ種類の本人の設定は 1 つだけ。持ち主のある行だけに効かせる
    # （NULL どうしを重なりとみなす DB でも、ほかの範囲の行で止まらないように）
    add_index :studio_settings, [:schema_type, :owner_id], unique: true,
              where: 'owner_id IS NOT NULL', name: INDEX_NAME
  end

  def down
    remove_index :studio_settings, name: INDEX_NAME
    remove_column :studio_settings, :owner_id
    remove_column :studio_settings, :version
  end
end
