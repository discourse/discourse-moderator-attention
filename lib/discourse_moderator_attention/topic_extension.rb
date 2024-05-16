# frozen_string_literal: true

module DiscourseModeratorAttention
  module TopicExtension
    extend ActiveSupport::Concern

    prepended { attr_accessor :requires_review }
  end
end
