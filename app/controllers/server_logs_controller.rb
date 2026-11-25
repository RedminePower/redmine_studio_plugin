# frozen_string_literal: true

# Server Logs API
#
# Redmine のログフォルダー（log）の直下にあるファイルの一覧と、ファイルの範囲のバイトを返す汎用の API。
# 絞り込み・集計はしない（呼ぶ側で行う）。システム管理者だけが使える。
#
# - GET /server_logs.json           … ファイルの一覧と、今 Redmine が書いているファイルの名前
# - GET /server_logs/content.json   … ファイルの範囲のバイト（成功のときは JSON ではなくバイトをそのまま返す）
#
# 失敗のときの本文は、どれも {"errors":[…]}。
class ServerLogsController < ApplicationController
  OFFSET_FORMAT = /\A\d+\z/
  LENGTH_FORMAT = /\A[1-9]\d*\z/
  FINGERPRINT_FORMAT = /\A\d+:[0-9a-f]*\z/
  RETRY_AFTER_SECONDS = 2

  accept_api_auth :index, :content
  # 401・403 も {"errors":[…]} で返すため、本体の require_login・require_admin の代わりに自分で確かめる
  skip_before_action :check_if_login_required
  before_action :require_admin_api

  # GET /server_logs.json
  def index
    render json: {
      server_logs: {
        log_file: log_directory.current_log_file_name,
        files: log_directory.list
      }
    }
  end

  # GET /server_logs/content.json?name=…&offset=…&length=…&fingerprint=…
  def content
    offset, length, fingerprint = content_params
    return if performed?

    name = log_directory.find_name(params[:name])
    return render_json_errors(404, 'not found') if name.nil?

    result = RedmineStudioPlugin::ServerLogs::ReadSlots.with_slot do
      log_directory.open_file(name) { |file| respond_with_range(file, offset, length, fingerprint) } || :not_found
    end

    if result == :busy
      response.headers['Retry-After'] = RETRY_AFTER_SECONDS.to_s
      render_json_errors(429, 'too many concurrent reads')
    elsif result == :not_found
      render_json_errors(404, 'not found')
    end
  end

  private

  def log_directory
    RedmineStudioPlugin::ServerLogs::LogDirectory
  end

  def require_admin_api
    if !User.current.logged?
      response.headers['WWW-Authenticate'] = 'Basic realm="Redmine API"'
      render_json_errors(401, 'authentication required')
    elsif !RedmineStudioPlugin::ServerLogs::AdminAccess.allowed?(User.current, request)
      render_json_errors(403, 'administrator required')
    end
  end

  def content_params
    errors = []
    errors << 'name is required' if params[:name].blank?
    errors << 'offset must be an integer of 0 or more' unless params[:offset].to_s.match?(OFFSET_FORMAT)
    if params.key?(:length) && !params[:length].to_s.match?(LENGTH_FORMAT)
      errors << 'length must be an integer of 1 or more'
    end
    if params.key?(:fingerprint) && !valid_fingerprint?(params[:fingerprint])
      errors << 'fingerprint is invalid'
    end
    return render_json_errors(422, *errors) if errors.any?

    length = params.key?(:length) ? params[:length].to_i : RedmineStudioPlugin::ServerLogs::RangeReader::DEFAULT_LENGTH
    [params[:offset].to_i, length, params[:fingerprint]]
  end

  # 一覧が返す形（対象は 4096 バイトまで）だけを受け付ける。大きなバイト数でファイル全体を読ませない
  def valid_fingerprint?(value)
    value.is_a?(String) && value.match?(FINGERPRINT_FORMAT) &&
      value.split(':', 2).first.to_i <= RedmineStudioPlugin::ServerLogs::LogDirectory::FINGERPRINT_BYTES
  end

  # gzip を受け付けるか（q=0 は断りの意味なので除く）
  def accept_gzip?
    request.headers['Accept-Encoding'].to_s.split(',').any? do |part|
      coding, *opts = part.strip.split(';').map(&:strip)
      next false unless coding.to_s.casecmp?('gzip') || coding == '*'

      q = opts.find { |o| o.start_with?('q=') }
      q.nil? || q.delete_prefix('q=').to_f.positive?
    end
  end

  # 開いたファイルから範囲を読んで返す。戻り値は with_slot / open_file に :not_found でないことを伝えるための true
  def respond_with_range(file, offset, length, fingerprint)
    response.headers['Cache-Control'] = 'no-store'
    response.headers['X-Server-Log-Size'] = file.size.to_s

    if fingerprint && !log_directory.same_fingerprint?(file, fingerprint)
      render status: 409, json: {
        errors: ['fingerprint does not match the current file'],
        fingerprint: log_directory.fingerprint(file)
      }
      return true
    end

    result = RedmineStudioPlugin::ServerLogs::RangeReader.read(file, offset, length, gzip: accept_gzip?)

    response.headers['X-Server-Log-Length'] = result.length.to_s
    if result.gzipped
      response.headers['Content-Encoding'] = 'gzip'
      response.headers['Vary'] = 'Accept-Encoding'
    end
    send_data result.body, type: 'application/octet-stream', disposition: 'inline'
    true
  end

  def render_json_errors(status, *messages)
    render status: status, json: { errors: messages }
  end
end
