# frozen_string_literal: true

module RedmineStudioPlugin
  module DateIndependent
    module IssuePatch

      def soonest_start(reload=false)
        if @soonest_start.nil? || reload
          relations_to.reload if reload
          dates = relations_to.collect{|relation| relation.successor_soonest_start}
          p = @parent_issue || parent
          if p && needs_derived
            dates << p.soonest_start
          end

          @soonest_start = dates.compact.max
        end
        @soonest_start
      end

      def dates_derived?
        !leaf? && needs_derived
      end

      def needs_derived
        # 全体の設定で「子チケットの値から算出」が選択されていなかったら連動しない
        if Setting.parent_issue_dates != 'derived'
          return false
        end

        settings = ::DateIndependent.where(is_enabled: true).order(:id).select {|s| s.project_ids.include?(self.project.id) }
        # 「有効」かつ「対象プロジェクト」にチケットのプロジェクトを含む設定が無ければ連動させる
        if settings.empty?
          return true
        end

        settings_with_calculate_status = settings.select {|t| t.calculate_status_ids.present? }
        # 「適用しないステータス」が設定されていなければ連動しない
        if settings_with_calculate_status.empty?
          return false
        end

        # チケットのステータスと「適用しないステータス」が一致する設定があれば連動させる
        settings_with_calculate_status.each {|t|
          if t.calculate_status_ids.include?(status_id)
            return true
          end
        }

        # チケットのステータスが「適用しないステータス」になければ連動させない
        return false
      end

    end
  end
end
