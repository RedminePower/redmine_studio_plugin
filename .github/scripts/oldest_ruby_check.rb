# frozen_string_literal: true

# Checks that the plugin's Ruby code can run on the oldest supported Ruby (see CONTRIBUTING.md "対応する Ruby").
# Run it with that Ruby (the workflow uses the official Docker image):
#
#   ruby .github/scripts/oldest_ruby_check.rb            # check the files tracked by git
#   ruby .github/scripts/oldest_ruby_check.rb --self-test
#
# 1. Syntax: every Ruby file is compiled by this Ruby. Newer syntax (numbered block parameters, endless ranges, ...) fails here.
# 2. Methods: newer core methods compile fine and only fail when they are called, so their calls are searched for.
#    A line can opt out with the comment "oldest-ruby-ok" (e.g. when the receiver is our own object that defines the method).

require 'ripper'
require 'open3'

module OldestRubyCheck
  # Methods added to the core classes after Ruby 2.5 that a Redmine plugin is likely to call.
  # Names that Rails (ActiveSupport) also adds to the same classes are left out (e.g. Hash#except).
  NEWER_METHODS = {
    'filter' => '2.6 (Array/Hash/Enumerable#filter; use select)',
    'filter!' => '2.6 (Array/Hash#filter!; use select!)',
    'then' => '2.6 (Kernel#then; use yield_self)',
    'difference' => '2.6 (Array#difference; use -)',
    'union' => '2.6 (Array#union; use |)',
    'chain' => '2.6 (Enumerable#chain)',
    'filter_map' => '2.7 (Enumerable#filter_map; use map { ... }.compact)',
    'tally' => '2.7 (Enumerable#tally; use group_by + count)',
    'intersection' => '2.7 (Array#intersection; use &)',
    'produce' => '2.7 (Enumerator.produce)',
    'intersect?' => '3.1 (Array#intersect?; use (a & b).any?)'
  }.freeze

  # Calls whose keyword argument is newer: Integer("x", exception: false) and friends (2.6)
  EXCEPTION_KEYWORD_CALLS = %w[Integer Float Rational Complex].freeze

  RUBY_EXTENSIONS = %w[.rb .rake .rsb].freeze
  RUBY_FILE_NAMES = %w[Gemfile Rakefile].freeze
  OPT_OUT = 'oldest-ruby-ok'

  Problem = Struct.new(:file, :line, :message)

  module_function

  def ruby_file?(path)
    RUBY_EXTENSIONS.include?(File.extname(path)) || RUBY_FILE_NAMES.include?(File.basename(path))
  end

  def erb_file?(path)
    path.end_with?('.erb')
  end

  def syntax_problems(file, source)
    RubyVM::InstructionSequence.compile(source, file)
    []
  rescue SyntaxError => e
    line = e.message[/:(\d+):/, 1].to_i
    [Problem.new(file, line, "syntax error on Ruby #{RUBY_VERSION}: #{e.message.lines.first.to_s.strip}")]
  end

  # Finds ".name" / "&.name" calls of the newer methods, and Integer(..., exception: ...) calls.
  def method_problems(file, source, line_offset = 0)
    tokens = Ripper.lex(source)
    lines = source.lines
    problems = []
    tokens.each_with_index do |((line, _col), type, text), i|
      if %i[on_period on_op].include?(type) && ['.', '&.'].include?(text)
        # the name may be on the next line when the line ends with "."
        j = i + 1
        j += 1 while tokens[j] && %i[on_sp on_ignored_nl on_nl on_comment].include?(tokens[j][1])
        name_token = tokens[j]
        next unless name_token && %i[on_ident on_kw on_const].include?(name_token[1])

        name = name_token[2]
        mark = tokens[j + 1]
        name += mark[2] if mark && %w[? !].include?(mark[2]) && mark[0] == [name_token[0][0], name_token[0][1] + name.length]
        next unless NEWER_METHODS.key?(name)

        problems << Problem.new(file, line + line_offset, "#{name} is not in Ruby 2.5 (added in #{NEWER_METHODS[name]})") unless opted_out?(lines, line)
      elsif type == :on_const && EXCEPTION_KEYWORD_CALLS.include?(text) && tokens[i + 1] && tokens[i + 1][2] == '('
        depth = 0
        tokens[(i + 1)..-1].each do |(_, t_type, t_text)|
          depth += 1 if t_text == '('
          depth -= 1 if t_text == ')'
          break if depth.zero?

          if depth == 1 && t_type == :on_label && t_text == 'exception:'
            problems << Problem.new(file, line + line_offset, "#{text}(..., exception:) is not in Ruby 2.5 (added in 2.6)") unless opted_out?(lines, line)
            break
          end
        end
      end
    end
    problems
  end

  def opted_out?(lines, line)
    lines[line - 1].to_s.include?(OPT_OUT)
  end

  # The Ruby code in an ERB template, with each piece kept on its original line.
  def erb_ruby(source)
    code = source.gsub(/<%#.*?%>/m) { |c| "\n" * c.count("\n") }
    # Text outside the tags keeps only its line breaks; each tag keeps its code, so line numbers stay the same
    code.gsub(/<%[=-]?(.*?)-?%>|[^\n]/m) { Regexp.last_match(1) ? "#{Regexp.last_match(1)};" : '' }
  end

  def check_file(file, source)
    if erb_file?(file)
      method_problems(file, erb_ruby(source))
    else
      syntax_problems(file, source) + method_problems(file, source)
    end
  end

  def tracked_files
    out, status = Open3.capture2('git', 'ls-files', '-z')
    raise 'git ls-files failed' unless status.success?

    out.split("\0").select { |f| ruby_file?(f) || erb_file?(f) }.reject { |f| f.start_with?('.github/scripts/') }
  end

  def run(files)
    problems = files.flat_map { |f| check_file(f, File.read(f, encoding: 'UTF-8')) }
    problems.each { |p| puts "#{p.file}:#{p.line}: #{p.message}" }
    puts "Checked #{files.size} files on Ruby #{RUBY_VERSION}: #{problems.empty? ? 'OK' : "#{problems.size} problem(s)"}"
    problems.empty?
  end

  def self_test
    cases = {
      'list.map { |x| x }.compact' => 0,
      'list.filter_map { |x| x }' => 1,
      'list&.filter_map { |x| x }' => 1,
      "list.\n  filter_map { |x| x }" => 1,
      "list\n  .filter_map { |x| x }" => 1,
      'a.filter? && a.select' => 0,
      'list.filter_map { |x| x } # oldest-ruby-ok' => 0,
      "# list.filter_map { |x| x }\n'.tally'" => 0,
      'counts = list.tally' => 1,
      'a.intersect?(b)' => 1,
      'a.select { |x| x }.then { |y| y }' => 1,
      'Integer(s, exception: false)' => 1,
      'Integer(s)' => 0,
      'foo(Integer(s), exception: false)' => 0,
      'def filter_map; end' => 0
    }
    failures = cases.reject { |src, n| method_problems('t.rb', src).size == n }
    failures.each { |src, n| puts "self-test: expected #{n} problem(s) for #{src.inspect}, got #{method_problems('t.rb', src).size}" }

    erb = "<% list.each do |x| %>\n<%= x.name %>\n<%# x.tally %>\n<%= list.filter_map(&:id).size %>\n<% end %>\n"
    erb_lines = method_problems('t.erb', erb_ruby(erb)).map(&:line)
    unless erb_lines == [4]
      failures[:erb] = 1
      puts "self-test: expected an ERB problem on line 4, got #{erb_lines.inspect}"
    end

    syntax = syntax_problems('t.rb', "[1, 2].each { p _1 }\n(1..).each { break }\n")
    if RUBY_VERSION < '2.7' && syntax.empty?
      failures[:syntax] = 1
      puts 'self-test: expected a syntax problem for numbered parameters'
    end

    puts "self-test: #{failures.empty? ? 'OK' : "#{failures.size} failure(s)"}"
    failures.empty?
  end
end

if $PROGRAM_NAME == __FILE__
  # --files-from LIST: check the files named in LIST (one per line) instead of asking git
  ok =
    if ARGV.include?('--self-test')
      OldestRubyCheck.self_test
    else
      list = ARGV.index('--files-from')
      files = list ? File.readlines(ARGV[list + 1], chomp: true).reject(&:empty?) : OldestRubyCheck.tracked_files
      files = files.reject { |f| f.start_with?('.github/scripts/') }
      OldestRubyCheck.run(files.select { |f| OldestRubyCheck.ruby_file?(f) || OldestRubyCheck.erb_file?(f) })
    end
  exit(ok ? 0 : 1)
end
