# frozen_string_literal: true

module StudioSettingUserNamesHelper
  # 返事に利用者（割り当ての相手・作った人・割り当てた人など）を書く。
  # 見る人から Redmine で見えない人（User.visible の外）は、名前を出さず id だけにする。管理者には全員の名前を出す
  def api_user_ref(api, key, user)
    return unless user

    if studio_setting_user_visible?(user.id)
      api.__send__(key, :id => user.id, :name => user.name)
    else
      api.__send__(key, :id => user.id)
    end
  end

  # 割り当て 1 件を返事に書く。
  # XML の要素名は studio_setting_assignment にそろえる。redmine-net-api は XmlRoot の要素名でデシリアライズするため
  def render_api_studio_setting_assignment(api, assignment)
    api.studio_setting_assignment do
      api.id assignment.id
      api.setting_id assignment.setting_id
      api.assigned_on assignment.assigned_on
      api_user_ref(api, :user, assignment.user)
      api_user_ref(api, :assigned_by, assignment.assigned_by)
    end
  end

  private

  # 同じ人が何度出ても、1 回の返事の中では 1 回だけ引く
  def studio_setting_user_visible?(user_id)
    return true if User.current.admin?

    @studio_setting_user_visible ||= Hash.new { |h, id| h[id] = User.visible(User.current).where(id: id).exists? }
    @studio_setting_user_visible[user_id]
  end
end
