# frozen_string_literal: true

class TeamsButtonController < ApplicationController
  before_action :require_login

  # 頼んだ人から見える、有効な利用者のメールアドレスを返す。見えない人・ロック中の人・いない人は同じ返事（email: nil）にする。
  # メールアドレスを隠している人は、本体の利用者の API と同じく管理者にだけ返し、ほかの人には理由（hidden）を付けて返さない
  def user_email
    user = User.visible.active.where(type: 'User').find_by(id: params[:id])
    return render(json: { email: nil }) unless user
    return render(json: { email: nil, reason: 'hidden' }) if user.pref.hide_mail && !User.current.admin?

    render json: { email: user.mail }
  end
end
