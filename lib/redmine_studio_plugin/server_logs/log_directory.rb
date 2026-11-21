# frozen_string_literal: true

require 'digest'
require 'zlib'
require 'stringio'

module RedmineStudioPlugin
  module ServerLogs
    # Redmine のログフォルダーの直下にあるファイルを、安全に一覧・読み出しする。
    #
    # 守り:
    # - ログフォルダーは最初に使うときに 1 回だけ決め、実際の場所（realpath）にする
    # - 名前は Dir.children に完全に一致するものだけを使う（パスを組み立ててから存在を調べない）
    # - ファイルは開いてから、開いたものの stat で「普通のファイル・ハードリンクが 1 つ・開く前の lstat と同じもの」を確かめる
    # - 印・大きさ・読むバイトは、すべて開いたファイルから取る
    module LogDirectory
      # 見分けの印の対象にする先頭のバイト数
      FINGERPRINT_BYTES = 4096
      # 名前に使えない文字
      INVALID_NAME_CHARS = %r{[/\\:\x00]}
      GZIP_MAGIC = "\x1f\x8b".b

      OPEN_FLAGS = File::RDONLY |
                   (defined?(File::NONBLOCK) ? File::NONBLOCK : 0) |
                   (defined?(File::NOFOLLOW) ? File::NOFOLLOW : 0) |
                   (defined?(File::BINARY) ? File::BINARY : 0)

      # 開いたログのファイル。io・大きさ・更新日時・圧縮されているか
      OpenedFile = Struct.new(:name, :io, :size, :mtime, :compressed)

      module_function

      # ログフォルダーの実際の場所。無い・決められないときは nil
      def path
        return @path if defined?(@path)

        @path = begin
          File.realpath(File.dirname(Rails.application.config.paths['log'].first))
        rescue StandardError => e
          Rails.logger.warn "server_logs: log directory is not available: #{e.class} #{e.message}"
          nil
        end
      end

      # 今 Redmine のロガーが書いているファイルの名前。ファイルに書いていない・ログフォルダーの外なら nil
      def current_log_file_name
        dir = path
        return nil if dir.nil?

        logger_file_paths.each do |file_path|
          real = realpath_or_nil(file_path)
          return File.basename(real) if real && same_path?(File.dirname(real), dir)
        end
        nil
      rescue StandardError
        nil
      end

      # 読めるファイルの一覧（名前の順）。ログフォルダーが無い・読めないときは空
      def list
        dir = path
        return [] if dir.nil?

        children_of(dir).sort.filter_map do |name|
          next unless valid_name?(name)

          with_open(dir, name) do |file|
            entry = {
              name: file.name,
              size: file.size,
              updated_on: file.mtime.xmlschema(0),
              fingerprint: fingerprint(file)
            }
            entry[:compressed] = true if file.compressed
            entry
          end
        end
      end

      # 一覧に並ぶ名前のうち、name に一致するもの（Windows では大文字・小文字を区別しない）。無ければ nil
      def find_name(name)
        dir = path
        return nil if dir.nil? || !name.is_a?(String)

        wanted = utf8(name)
        return nil unless valid_name?(wanted)

        children_of(dir).find { |child| valid_name?(child) && same_name?(utf8(child), wanted) }
      end

      # 一覧に並ぶ名前のファイルを開き、確かめてからブロックに渡す。並べないもの・開けないものなら nil を返す
      def open_file(name, &block)
        dir = path
        return nil if dir.nil?

        with_open(dir, name, &block)
      end

      # 先頭 bytes バイト（圧縮されたファイルは展開した先頭）の見分けの印。取れなければ nil
      def fingerprint(file, bytes = FINGERPRINT_BYTES)
        head = read_head(file, bytes)
        return nil if head.nil?

        format_fingerprint(head)
      end

      # 渡された印が、今のファイルと同じか
      def same_fingerprint?(file, expected)
        bytes = expected.split(':', 2).first.to_i
        head = read_head(file, bytes)
        return false if head.nil? || head.bytesize < bytes

        format_fingerprint(head) == expected
      end

      def format_fingerprint(head)
        head.empty? ? '0:' : "#{head.bytesize}:#{Digest::SHA256.hexdigest(head)}"
      end

      # ---- ここから内部 ----------------------------------------------------

      def children_of(dir)
        Dir.children(dir)
      rescue SystemCallError
        []
      end

      def realpath_or_nil(file_path)
        File.realpath(file_path)
      rescue SystemCallError
        nil
      end

      def valid_name?(name)
        name = utf8(name)
        name.valid_encoding? && !name.empty? && !name.start_with?('.') && !name.match?(INVALID_NAME_CHARS)
      end

      def utf8(name)
        name.dup.force_encoding(Encoding::UTF_8)
      end

      def same_name?(a, b)
        windows? ? a.casecmp?(b) : a == b
      end

      def same_path?(a, b)
        windows? ? a.casecmp?(b) : a == b
      end

      def windows?
        Gem.win_platform?
      end

      # 名前のファイルを開き、普通のファイル・ハードリンクが 1 つ・開く前と同じもの、を確かめてから yield する
      def with_open(dir, name)
        file_path = File.join(dir, name)
        before = File.lstat(file_path)
        return nil unless before.file? && before.nlink == 1

        io = File.new(file_path, OPEN_FLAGS)
        begin
          st = io.stat
          return nil unless st.file? && st.nlink == 1 && same_file?(before, st)

          opened = OpenedFile.new(utf8(name), io, st.size, st.mtime, false)
          opened.compressed = gzip?(opened)
          yield opened
        ensure
          io.close
        end
      rescue SystemCallError, IOError
        nil
      end

      # 開く前の lstat と開いた後の stat が同じファイルか（調べた後にすり替えられていないか）。
      # Windows の Ruby は、名前で調べたときと開いたファイルで調べたときに dev・ino の取れ方が違うことがあるため、
      # 両方で ino が取れたときだけ ino で比べる
      def same_file?(before, opened)
        if windows?
          before.ino.zero? || opened.ino.zero? || before.ino == opened.ino
        else
          before.dev == opened.dev && before.ino == opened.ino
        end
      end

      def gzip?(file)
        return false unless file.name.end_with?('.gz')

        file.io.seek(0)
        file.io.read(2) == GZIP_MAGIC
      end

      # 先頭 bytes バイト（圧縮されたファイルは展開した先頭）。読めなければ nil
      def read_head(file, bytes)
        return ''.b if bytes <= 0

        file.io.seek(0)
        if file.compressed
          gz = Zlib::GzipReader.new(file.io)
          begin
            (gz.read(bytes) || '').b
          ensure
            gz.finish
          end
        else
          (file.io.read(bytes) || '').b
        end
      rescue Zlib::Error, SystemCallError, IOError
        nil
      end

      # Rails のロガー（BroadcastLogger のときは中のロガーも）が書いているファイルのパス
      def logger_file_paths
        loggers = [Rails.logger]
        loggers += Rails.logger.broadcasts if Rails.logger.respond_to?(:broadcasts)
        loggers.filter_map do |logger|
          logdev = logger.instance_variable_get(:@logdev)
          next if logdev.nil?

          if logdev.respond_to?(:filename) && logdev.filename
            logdev.filename.to_s
          elsif logdev.respond_to?(:dev) && logdev.dev.is_a?(File)
            logdev.dev.path
          end
        end
      end
    end
  end
end
