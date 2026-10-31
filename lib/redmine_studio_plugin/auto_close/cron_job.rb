# frozen_string_literal: true

require 'etc'
require 'open3'
require 'rbconfig'
require 'shellwords'

module RedmineStudioPlugin
  module AutoClose
    # 期限切れ時の自動クローズを毎日動かす cron の行を扱う（install / uninstall から使う）
    #
    # 扱うのは「この Redmine の行」だけ:
    # コメントでなく、タスク名を含み、cd の先がこの Redmine のフォルダーの行。
    # 別の Redmine の行・コメントにした行・/etc/cron.d などの行には書き込まない。
    module CronJob
      TASK = 'redmine_studio_plugin:auto_close:check_expired'
      LEGACY_TASK = 'redmine_auto_close:check_expired'
      DEFAULT_SCHEDULE = '0 3 * * *'
      SYSTEM_PATH = '/usr/local/bin:/usr/bin:/bin'
      # cron の中と同じ条件（環境変数を引き継がず、PATH は /usr/bin:/bin だけ）
      CRON_ENV = { 'PATH' => '/usr/bin:/bin' }.freeze
      # crontab がまだ無いときの crontab -l の文（cronie などは "no crontab for"、busybox は "can't open ... No such file"）
      NO_CRONTAB = /no crontab|can't open .*no such file/i

      # gem・bundler の置き場所を決める環境変数。install を実行したときに設定されていれば、行に付ける
      # （BUNDLE_* をまとめて写さないのは、認証情報を入れる変数があり crontab に平文で残るため）
      GEM_ENV_NAMES = %w[GEM_HOME GEM_PATH BUNDLE_APP_CONFIG BUNDLE_PATH BUNDLE_GEMFILE].freeze

      module_function

      # cron の中で bundle・rake が見つかる PATH（今動いている Ruby と gem のコマンドのフォルダーを前に足す）
      # bundle exec が GEM_HOME を書き換えていることがあるため、書き換える前の GEM_HOME のコマンドのフォルダーも足す
      def cron_path(ruby_dir = File.dirname(RbConfig.ruby), gem_bindirs = [Gem.bindir, original_gem_bindir].compact)
        ([ruby_dir, *gem_bindirs] + SYSTEM_PATH.split(':')).uniq.join(':')
      end

      def original_gem_bindir
        home = original_env['GEM_HOME']
        home.to_s.empty? ? nil : File.join(home, 'bin')
      end

      # 行に付ける環境変数（PATH と、設定されている gem・bundler の置き場所）
      # bundle exec の中では bundler が書き換えるため、書き換える前の値（Bundler.original_env）を使う
      # 改行を含む値は crontab の行が割れるため付けない
      def cron_env(env = original_env, path = cron_path)
        GEM_ENV_NAMES.each_with_object({ 'PATH' => path }) do |name, result|
          value = env[name].to_s
          result[name] = value unless value.empty? || value.include?("\n")
        end
      end

      def original_env
        defined?(Bundler) && Bundler.respond_to?(:original_env) ? Bundler.original_env : ENV.to_h
      end

      def command(root, env, rake_args)
        vars = env.map { |name, value| "#{name}=#{quote(value)}" }.join(' ')
        "cd #{quote(root.to_s)} && #{vars} bundle exec rake #{rake_args}"
      end

      # シェルの引用。記号を含む値は単一引用で包む
      # （Shellwords.escape は % を \% にするため、そのあと crontab 用に % を \% にすると \\% になり、cron がそこで行を切る）
      def quote(value)
        return value if value.match?(%r{\A[A-Za-z0-9_\-.,:+/@]+\z})

        "'#{value.gsub("'", %q('\\\\''))}'"
      end

      def build_line(root, env, schedule = DEFAULT_SCHEDULE)
        body = command(root, env, "#{TASK} RAILS_ENV=production >> log/auto_close.log 2>&1")
        # crontab では % が改行の意味になるため \% にする
        "#{schedule} #{body.gsub('%', '\%')}"
      end

      # 登録する行が cron の中で動くかを、rake を起動するところまで試す
      def self_test(root, env = cron_env)
        output, status = Open3.capture2e(CRON_ENV.merge('HOME' => home_dir), 'sh', '-c',
                                         command(root, env, '--version'), unsetenv_others: true)
        [status.success?, output]
      end

      # 行がこの Redmine のタスクの行か
      def this_redmine?(line, root)
        return false unless task_line?(line, TASK)

        target = cd_target(line)
        !target.nil? && same_dir?(target, root.to_s)
      end

      # コメントでなく、タスク名を含む行か
      def task_line?(line, task)
        !line.lstrip.start_with?('#') && line.include?(task)
      end

      # タスク名を含むが、この Redmine の行と判断しなかった行（別の Redmine の行・cd の先が読み取れない行）
      def other_lines(current, root)
        current.lines.map(&:chomp).select { |l| task_line?(l, TASK) && !this_redmine?(l, root) }
      end

      # 行の時刻の欄（@daily などにも対応）
      def schedule_of(line)
        fields = line.strip.split(/\s+/)
        fields.first.start_with?('@') ? fields.first : fields.first(5).join(' ')
      end

      def cd_target(line)
        words = Shellwords.split(line.gsub('\%', '%'))
        index = words.index('cd')
        index && words[index + 1]&.sub(/;\z/, '')
      rescue ArgumentError
        nil
      end

      def same_dir?(a, b)
        normalize_dir(a) == normalize_dir(b)
      end

      def normalize_dir(dir)
        File.realpath(dir)
      rescue SystemCallError
        File.expand_path(dir).chomp('/')
      end

      # install: 自分の crontab の中身から、新しい中身と変わった行を求める
      # registered_elsewhere が true なら（/etc/cron.d などに登録がある）、自分の crontab には足さない
      def plan_install(current, root, env, registered_elsewhere: false)
        line = nil
        removed = []
        lines = current.lines.map(&:chomp).each_with_object([]) do |l, result|
          if task_line?(l, LEGACY_TASK)
            # 旧プラグイン（redmine_auto_close）は install で消えるので、その行はすべて外す
            removed << l
          elsif this_redmine?(l, root)
            if line || registered_elsewhere
              removed << l
            else
              # 1 本目は新しい形に置き換える（時刻は引き継ぐ）
              line = build_line(root, env, schedule_of(l))
              removed << l unless l == line
              result << line
            end
          else
            result << l
          end
        end
        if line.nil? && !registered_elsewhere
          line = build_line(root, env)
          lines << line
        end
        # added: 新しく足した行・置き換えた行（前と同じ行なら nil）
        added = line unless line.nil? || current.lines.map(&:chomp).include?(line)
        { text: to_text(lines), removed: removed, added: added, line: line }
      end

      # uninstall: 自分の crontab からこの Redmine の行を消す
      def plan_uninstall(current, root)
        removed, kept = current.lines.map(&:chomp).partition { |l| this_redmine?(l, root) }
        { text: to_text(kept), removed: removed }
      end

      def to_text(lines)
        lines.empty? ? '' : lines.join("\n") + "\n"
      end

      # /etc/crontab・/etc/cron.d にあるこの Redmine の行（[ファイル, 行] の並び）
      def system_entries(root, files = ['/etc/crontab'] + Dir.glob('/etc/cron.d/*'))
        files.select { |f| File.file?(f) && File.readable?(f) }.flat_map do |f|
          File.readlines(f, chomp: true).select { |l| this_redmine?(l, root) }.map { |l| [f, l] }
        end
      end

      # 実行した利用者の crontab を読む。読めなかったら nil と理由を返す（そのときは書き込まない）
      # crontab コマンドが無い環境（Docker の公式イメージなど）では、理由は :no_crontab_command
      def read_crontab
        out, err, status = Open3.capture3('crontab', '-l')
        return [out, nil] if status.success?
        return ['', nil] if err =~ NO_CRONTAB

        [nil, err.strip]
      rescue Errno::ENOENT
        [nil, :no_crontab_command]
      rescue SystemCallError => e
        [nil, e.message]
      end

      def write_crontab(text)
        out, status = Open3.capture2e('crontab', '-', stdin_data: text)
        [status.success?, out.strip]
      rescue SystemCallError => e
        [false, e.message]
      end

      def user_name
        Etc.getpwuid(Process.uid).name
      rescue StandardError
        ENV['USER'] || Process.uid.to_s
      end

      # cron と同じく、/etc/passwd にある利用者のホーム（sudo -u では HOME が実行した人のまま残ることがある）
      def home_dir
        Etc.getpwuid(Process.uid).dir
      rescue StandardError
        Dir.home
      end
    end
  end
end
