# frozen_string_literal: true

# ロードマップのバージョン画面で「関連するチケット」の代わりに表示する一覧の設定。
# 上から順（position）に照合し、最初にプロジェクトパターンが当てはまった有効な設定を使う。
# acts_as_positioned は Redmine 6 以降 ApplicationRecord にだけ組み込まれるため、ApplicationRecord を継承する
class RoadmapDisplay < ApplicationRecord
  STATUS_SCOPES = %w[all open closed].freeze
  DEFAULT_COLUMN_NAMES = %w[tracker id subject status assigned_to done_ratio updated_on].freeze

  acts_as_positioned

  # Rails 7.1+ では serialize の引数が変更された
  if Rails::VERSION::MAJOR > 7 || (Rails::VERSION::MAJOR == 7 && Rails::VERSION::MINOR >= 1)
    serialize :column_names, type: Array, coder: YAML
    serialize :sort_criteria, type: Array, coder: YAML
    serialize :totalable_names, type: Array, coder: YAML
  else
    serialize :column_names, Array
    serialize :sort_criteria, Array
    serialize :totalable_names, Array
  end

  validates :name, presence: true, length: { maximum: 255 }
  validates :status_scope, inclusion: { in: STATUS_SCOPES }
  validate :validate_project_pattern

  scope :sorted, -> { order(:position) }
  scope :enabled, -> { where(is_enabled: true) }

  after_initialize :set_default_values, if: :new_record?

  # そのプロジェクトで使う設定（無ければ nil = Redmine 標準の表示）
  def self.for_project(project)
    return nil unless project

    enabled.sorted.detect { |display| display.match?(project) }
  end

  def project_regexp
    return nil if project_pattern.blank?

    Regexp.new(project_pattern)
  rescue RegexpError
    nil
  end

  def match?(project)
    return true if project_pattern.blank?

    regexp = project_regexp
    regexp ? regexp.match?(project.identifier) : false
  end

  # パターンに当てはまるプロジェクトを、上の設定に先に取られるかどうかで分けて返す
  # @return [Hash] { applied: [Project], overridden: [[Project, RoadmapDisplay]] }
  def project_matches
    higher = self.class.enabled.sorted.to_a.select { |d| d != self && d.above?(self) }
    applied = []
    overridden = []
    Project.order(:lft).each do |project|
      next unless match?(project)

      winner = higher.detect { |d| d.match?(project) }
      winner ? overridden << [project, winner] : applied << project
    end
    { applied: applied, overridden: overridden }
  end

  def above?(other)
    return true if other.position.nil?
    return false if position.nil?

    position < other.position
  end

  # 表示中のバージョンのチケットを、この設定の列・グループ・並び順で取得するクエリ
  def build_query(version = nil)
    query = IssueQuery.new(name: '_', filters: {})
    query.user = User.current
    query.column_names = column_names.presence || DEFAULT_COLUMN_NAMES
    query.group_by = group_by.presence
    query.sort_criteria = sort_criteria.presence || [%w[id desc]]
    query.totalable_names = totalable_names.presence || []
    query.add_filter('fixed_version_id', '=', [version.id.to_s]) if version
    case status_scope
    when 'open' then query.add_filter('status_id', 'o', [''])
    when 'closed' then query.add_filter('status_id', 'c', [''])
    else query.add_filter('status_id', '*', [''])
    end
    query
  end

  def copy
    self.class.new(
      attributes.except('id', 'position', 'created_at', 'updated_at')
        .merge('name' => ::I18n.t(:rd_text_copy_of, name: name))
    )
  end

  private

  def set_default_values
    self.column_names = DEFAULT_COLUMN_NAMES.dup if column_names.blank?
    self.sort_criteria = [%w[id desc]] if sort_criteria.blank?
    self.totalable_names ||= []
    self.status_scope ||= 'all'
  end

  def validate_project_pattern
    return if project_pattern.blank?

    Regexp.new(project_pattern)
  rescue RegexpError => e
    errors.add(:project_pattern, :invalid)
    Rails.logger.info "#{self.class} invalid project_pattern=#{project_pattern}: #{e.message}"
  end
end
