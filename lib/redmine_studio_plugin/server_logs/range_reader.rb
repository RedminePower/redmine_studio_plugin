# frozen_string_literal: true

require 'zlib'
require 'stringio'

module RedmineStudioPlugin
  module ServerLogs
    # 開いたログのファイルから、指定した範囲のバイトを読む。
    #
    # 1 回に返す量の上限：送る量（圧縮した後）がおよそ MAX_SEND_BYTES になるまで、または読んだ量が MAX_READ_BYTES になるまで。
    # 回線が遅い環境で 1 回の応答が長くなりすぎず、呼ぶ回数（往復）も多くなりすぎないようにする。
    module RangeReader
      DEFAULT_LENGTH = 16 * 1024 * 1024
      MAX_READ_BYTES = 16 * 1024 * 1024
      MAX_SEND_BYTES = 1024 * 1024
      CHUNK_BYTES = 256 * 1024
      GZIP_LEVEL = 1

      Result = Struct.new(:body, :length, :gzipped)

      module_function

      # file: LogDirectory::OpenedFile。gzip: 本文を gzip で圧縮するか（圧縮されたファイルは圧縮し直さない）
      def read(file, offset, length, gzip:)
        # offset が大きさ以上なら seek しない（大きすぎる数で失敗させない）
        return Result.new(''.b, 0, false) if offset >= file.size

        limit = [length, file.size - offset, MAX_READ_BYTES].min
        file.io.seek(offset)

        if gzip && !file.compressed
          read_gzipped(file.io, limit)
        else
          data = file.io.read([limit, MAX_SEND_BYTES].min) || ''.b
          Result.new(data, data.bytesize, false)
        end
      end

      def read_gzipped(io, limit)
        out = StringIO.new(''.b)
        gz = Zlib::GzipWriter.new(out, GZIP_LEVEL)
        read = 0
        while read < limit && out.size < MAX_SEND_BYTES
          chunk = io.read([CHUNK_BYTES, limit - read].min)
          break if chunk.nil? || chunk.empty?

          gz.write(chunk)
          read += chunk.bytesize
        end
        gz.finish
        Result.new(out.string, read, true)
      end
    end
  end
end
