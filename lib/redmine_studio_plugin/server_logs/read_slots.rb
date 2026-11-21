# frozen_string_literal: true

module RedmineStudioPlugin
  module ServerLogs
    # ログの読み出しを、サーバーごとに同時に SLOTS 個までにする。
    #
    # Redmine の tmp フォルダーに SLOTS 個のロックのファイルを置き、要求ごとにファイルを開き直して
    # どれかに flock(LOCK_EX | LOCK_NB) が取れたときだけ読む。開き直すので、Puma の同じプロセスの
    # スレッドどうしでも数えられる。プロセスが落ちてもロックは自然に外れる。
    # tmp に書けないときは、数えずに読む（機能を止めない。Redmine のログに 1 回だけ警告を書く）。
    module ReadSlots
      SLOTS = 2
      LOCK_FILE_PREFIX = 'redmine_studio_plugin_server_logs_read'

      module_function

      # 枠が取れたらブロックを実行してその値を返す。枠がすべてふさがっていれば、ブロックを実行せずに :busy を返す
      def with_slot
        lock = acquire
        return :busy if lock == :busy

        begin
          yield
        ensure
          lock.close if lock.is_a?(File)
        end
      end

      # 取れたロックのファイル・ふさがっていれば :busy・数えられなければ :uncounted
      def acquire
        SLOTS.times do |i|
          file = File.open(lock_path(i), File::RDWR | File::CREAT, 0o644)
          begin
            return file if file.flock(File::LOCK_EX | File::LOCK_NB)
          rescue StandardError
            file.close
            raise
          end
          file.close
        end
        :busy
      rescue SystemCallError, IOError, NotImplementedError => e
        warn_once(e)
        :uncounted
      end

      def lock_path(index)
        File.join(Rails.root.join('tmp').to_s, "#{LOCK_FILE_PREFIX}_#{index}.lock")
      end

      def warn_once(error)
        return if @warned

        @warned = true
        Rails.logger.warn "server_logs: concurrent read limit is disabled (#{error.class}: #{error.message})"
      end
    end
  end
end
