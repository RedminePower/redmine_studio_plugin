# frozen_string_literal: true

class DateIndependent < ActiveRecord::Base
  validates_presence_of :title

  validate :valid_action

  # Rails 7.1+ では serialize の引数が変更された
  if Rails::VERSION::MAJOR >= 7 && Rails::VERSION::MINOR >= 1
    serialize :project_ids, type: Array
    serialize :calculate_status_ids, type: Array
  else
    serialize :project_ids, Array
    serialize :calculate_status_ids, Array
  end

  def project_ids
    return super.presence&.map(&:to_i) || []
  end

  def project_ids=(values)
    super(values.map(&:to_i))
  end

  # プロジェクトの設定方法を project_pattern から project_ids に切り替えたので
  # project_pattern での設定が残っていたら、それをもとに project_ids を設定する
  def migrate_project_pattern
    if project_pattern.present?
      p_ids = Project.all.select { |p| p.identifier =~ Regexp.new(project_pattern) }.map(&:id)
      Rails.logger.info "#{self.class} id=#{id} title=#{title} migrate project_pattern=#{project_pattern} -> project_ids=#{p_ids}"
      self.project_ids = p_ids
      self.project_pattern = nil
      save
    end
  end

  def project_ids_label
    if project_ids.empty?
      ""
    else
      Project.where(id: project_ids).pluck(:name).join(", ")
    end
  end

  def calculate_status_ids
    return super.presence&.map(&:to_i) || []
  end

  def calculate_status_ids=(values)
    super(values.map(&:to_i))
  end

  # プロジェクトの設定方法を calculate_status_pattern から calculate_status_ids に切り替えたので
  # calculate_status_pattern での設定が残っていたら、それをもとに calculate_status_ids を設定する
  def migrate_calculate_status_pattern
    if calculate_status_pattern.present?
      s_ids = IssueStatus.all.select { |s| s.name =~ Regexp.new(calculate_status_pattern) }.map(&:id)
      Rails.logger.info "#{self.class} id=#{id} title=#{title} migrate calculate_status_pattern=#{calculate_status_pattern} -> calculate_status_ids=#{s_ids}"
      self.calculate_status_ids = s_ids
      self.calculate_status_pattern = nil
      save
    end
  end

  def calculate_status_ids_label
    if calculate_status_ids.empty?
      ""
    else
      IssueStatus.where(id: calculate_status_ids).pluck(:name).join(", ")
    end
  end

  def valid_action

    # プロジェクト情報は必須
    if project_ids.empty? && project_pattern.blank?
      errors.add(:project_ids, :invalid)
    end

    # プロジェクトパターンが設定されていた場合
    if project_pattern.present?
      begin
        Regexp.compile(project_pattern)
      rescue
        errors.add(:project_pattern, :invalid)
      end
    end

    # 連動させるステータスのパターンが設定されていた場合
    if calculate_status_pattern.present?
      begin
        Regexp.compile(calculate_status_pattern)
      rescue
        errors.add(:calculate_status_pattern, :invalid)
      end
    end

  end

  def available?
    is_enabled
  end
end
