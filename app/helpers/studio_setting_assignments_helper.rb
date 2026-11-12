# frozen_string_literal: true

module StudioSettingAssignmentsHelper
  # 割り当ての相手を返事に書く。見る人から見えない相手は、名前を出さず id だけにする
  # （割り当てで、見えない人をいない人と同じに扱うのと合わせる）
  def api_assignment_user(api, assignment)
    return unless assignment.user

    if assignment_user_visible?(assignment.user_id)
      api.user(:id => assignment.user.id, :name => assignment.user.name)
    else
      api.user(:id => assignment.user.id)
    end
  end

  private

  # 同じ人が何度出ても、1 回の返事の中では 1 回だけ引く
  def assignment_user_visible?(user_id)
    return true if User.current.admin?

    @assignment_user_visible ||= Hash.new { |h, id| h[id] = User.visible(User.current).where(id: id).exists? }
    @assignment_user_visible[user_id]
  end
end
