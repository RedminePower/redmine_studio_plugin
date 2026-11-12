# frozen_string_literal: true

module RedmineStudioPlugin
  module StudioSettings
    # 利用者を消したら、その人の本人の設定も消す（残すと、ほかの人の一覧に消えた人の設定が出続ける）
    module UserPatch
      def self.included(base)
        base.after_destroy :destroy_studio_user_settings
      end

      private

      def destroy_studio_user_settings
        # 本人の設定は論理削除を使わないので、物理削除で消す（割り当て・履歴も dependent で一緒に消える）
        ::StudioSetting.where(scope_type: ::StudioSetting::SCOPE_USER, scope_id: id).destroy_all
      end
    end
  end
end
