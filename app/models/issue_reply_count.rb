# frozen_string_literal: true

class IssueReplyCount < ActiveRecord::Base
  belongs_to :issue
end
