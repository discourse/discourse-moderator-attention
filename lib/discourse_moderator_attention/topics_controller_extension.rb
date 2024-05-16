# frozen_string_literal: true

module DiscourseModeratorAttention
  module TopicsControllerExtension
    extend ActiveSupport::Concern

    def timings
      result = super
      if current_user && current_user.moderator? && (topic_id = params["topic_id"].to_i) &&
           (timings = params["timings"])
        posts = timings.keys.map(&:to_i)
        record_moderator_timings(current_user.id, topic_id, posts)
      end
      result
    end

    def record_moderator_timings(user_id, topic_id, post_numbers)
      return if topic_id <= 0 || post_numbers.length <= 0

      sql = <<~SQL
        UPDATE moderator_post_views v
        SET last_viewed = :date
        FROM posts p
        WHERE p.id = v.post_id AND
              v.user_id = :user_id AND
              post_id IN (
                SELECT id FROM posts WHERE topic_id = :topic_id AND post_number IN (:post_numbers)
              )
        RETURNING p.post_number
      SQL

      args = { date: Time.zone.now, topic_id: topic_id, user_id: user_id }

      existing = DB.query_single(sql, args.merge(post_numbers: post_numbers))

      (post_numbers - existing).each do |number|
        begin
          sql = <<~SQL
            INSERT INTO moderator_post_views(last_viewed, post_id, user_id)

            VALUES(:date, (SELECT id FROM posts
                           WHERE topic_id = :topic_id AND post_number = :post_number),
                   :user_id)
          SQL
          DB.exec(sql, args.merge(post_number: number))
        rescue PG::UniqueViolation
          # skip
        end
      end
    end
  end
end
