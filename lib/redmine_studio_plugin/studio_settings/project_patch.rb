# frozen_string_literal: true

module RedmineStudioPlugin
  module StudioSettings
    # プロジェクトを消したら、そのプロジェクトの範囲の設定も消す
    # （残すと、割り当てられた人の一覧や管理者の一覧に出続け、ID が使い回される DB では別のプロジェクトの設定に見えてしまう）
    module ProjectPatch
      def self.included(base)
        base.after_destroy :destroy_studio_project_settings
      end

      private

      def destroy_studio_project_settings
        # 論理削除したものも含めて物理削除で消す（割り当て・履歴も dependent で一緒に消える）
        ::StudioSetting.where(scope_type: 'project', scope_id: id).destroy_all
      end
    end
  end
end
