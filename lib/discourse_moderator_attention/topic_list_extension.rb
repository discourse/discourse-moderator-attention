# frozen_string_literal: true

module DiscourseModeratorAttention
  module TopicListExtension
    extend ActiveSupport::Concern

    def load_topics
      topics = super

      if @current_user && @current_user.moderator?
        topic_ids = topics.map(&:id)
        sql = <<~SQL
          SELECT p.topic_id, MIN(post_number) as min_id
          FROM posts p
          JOIN topics t on t.id = p.topic_id
          LEFT JOIN moderator_post_views v ON p.id = v.post_id
          WHERE p.deleted_at IS NULL AND NOT p.hidden AND v.post_id IS NULL
            AND p.topic_id IN (:topic_ids)
            AND p.updated_at > :min_date
            AND t.archetype <> 'private_message'
          GROUP BY p.topic_id
        SQL

        min_date =
          (
            if SiteSetting.minimum_review_date.present?
              Date.parse(SiteSetting.minimum_review_date)
            else
              Date.parse("1970-01-01")
            end
          )

        requires_review = {}
        DB
          .query(sql, topic_ids: topic_ids, min_date: min_date)
          .each { |row| requires_review[row.topic_id] = row.min_id }

        topics.each { |t| t.requires_review = requires_review[t.id] }
      end

      topics
    end
  end
end
