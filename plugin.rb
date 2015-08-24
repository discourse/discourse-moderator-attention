# name: discourse-moderator-attention
# about: add icon next to all topics that were not views by moderators
# version: 0.1
# authors: Sam Saffron

PLUGIN_NAME = "discourse_moderator_attention".freeze

register_asset 'stylesheets/moderator-attention.scss'

after_initialize do

  module ::DiscourseModeratorAttention; end

  # Jimmy in our tracking table
  got_tracking_table = Topic.exec_sql "SELECT 1 FROM moderator_post_views LIMIT 1" rescue nil

  unless got_tracking_table
    Topic.transaction do
      Topic.exec_sql "CREATE TABLE moderator_post_views(
          post_id int not null,
          user_id int not null,
          last_viewed timestamp without time zone not null
        )"
      Topic.exec_sql "CREATE UNIQUE INDEX idx_moderator_post_views_post_id
                      ON moderator_post_views (post_id, user_id)"
    end
  end

  module ::DiscourseModeratorAttention::TopicsController
    def timings
      result = super
      if  current_user &&
          current_user.moderator? &&
          (topic_id = params["topic_id"].to_i) &&
          (timings = params["timings"])
        posts = timings.keys.map(&:to_i)
        record_moderator_timings(current_user.id, topic_id, posts)
      end
      result
    end


    def record_moderator_timings(user_id, topic_id, post_numbers)
      return unless topic_id > 0 && post_numbers.length > 0

      sql = <<SQL
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
      args = {
         date: Time.zone.now,
         topic_id: topic_id,
         user_id: user_id
      }


      result = Topic.exec_sql(sql, args.merge(post_numbers: post_numbers))

      existing = result.column_values(0).map(&:to_i)

      (post_numbers - existing).each do |number|
        begin
          sql = <<SQL
            INSERT INTO moderator_post_views(last_viewed, post_id, user_id)

            VALUES(:date, (SELECT id FROM posts
                           WHERE topic_id = :topic_id AND post_number = :post_number),
                   :user_id)
SQL
          Topic.exec_sql(sql, args.merge(post_number: number))
        rescue PG::UniqueViolation
          # skip
        end
      end
    end
  end

  require_dependency 'topics_controller'
  class ::TopicsController
    prepend ::DiscourseModeratorAttention::TopicsController
  end

  require_dependency 'topic_view_serializer'
  class ::TopicViewSerializer
  end

  require_dependency 'topic'
  class ::Topic
    attr_accessor :requires_review
  end

  require_dependency 'topic_list'
  module ::DiscourseModeratorAttention::TopicList
    def load_topics
      topics = super

      if @current_user && @current_user.moderator?
        topic_ids = topics.map(&:id)
        sql = <<SQL
        SELECT p.topic_id, MIN(post_number)
        FROM posts p
        LEFT JOIN moderator_post_views v ON p.id = v.post_id
        WHERE p.deleted_at IS NULL AND NOT p.hidden AND v.post_id IS NULL
          AND p.topic_id IN (:topic_ids)
        GROUP BY p.topic_id
SQL

        requires_review = {}
        Topic.exec_sql(sql, topic_ids: topic_ids).values.each do |row|
          requires_review[row[0].to_i] = row[1].to_i
        end

        topics.each do |t|
          t.requires_review = requires_review[t.id]
        end
      end

      topics
    end
  end

  class ::TopicList
    prepend ::DiscourseModeratorAttention::TopicList
  end


  require_dependency 'topic_list_item_serializer'

  class ::TopicListItemSerializer
    attributes :requires_review

    def include_requires_review?
      scope.is_moderator? && object.requires_review
    end

    def requires_review
      object.requires_review
    end
  end

end
