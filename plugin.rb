# frozen_string_literal: true

# name: discourse-moderator-attention
# about: add icon next to all topics that were not views by moderators
# version: 0.1
# authors: Sam Saffron
# url: https://github.com/discourse/discourse-moderator-attention

register_asset "stylesheets/moderator-attention.scss"

register_svg_icon "asterisk" if respond_to?(:register_svg_icon)

after_initialize do
  module ::DiscourseModeratorAttention
    PLUGIN_NAME = "discourse_moderator_attention"
  end

  require_relative "lib/discourse_moderator_attention/topics_controller_extension"
  require_relative "lib/discourse_moderator_attention/topic_list_extension"
  require_relative "lib/discourse_moderator_attention/topic_extension"

  begin
    # Jimmy in our tracking table
    got_tracking_table =
      begin
        DB.query_single("SELECT 1 FROM moderator_post_views LIMIT 1")
      rescue StandardError
        nil
      end
    unless got_tracking_table
      Topic.transaction do
        DB.exec "CREATE TABLE moderator_post_views(
            post_id int not null,
            user_id int not null,
            last_viewed timestamp without time zone not null
          )"
        DB.exec "CREATE UNIQUE INDEX idx_moderator_post_views_post_id
                        ON moderator_post_views (post_id, user_id)"
      end
    end
  rescue ActiveRecord::NoDatabaseError
  end

  reloadable_patch do
    TopicsController.prepend(DiscourseModeratorAttention::TopicsControllerExtension)
    TopicList.prepend(DiscourseModeratorAttention::TopicListExtension)
    Topic.prepend(DiscourseModeratorAttention::TopicExtension)
  end

  add_to_serializer(
    :topic_view,
    :unreviewed_post_numbers,
    include_condition: -> { scope.is_moderator? && !object.topic.private_message? },
  ) do
    sql = <<~SQL
      SELECT post_number
      FROM posts p
      LEFT JOIN moderator_post_views v ON v.post_id = p.id
      WHERE p.deleted_at IS NULL AND
            p.topic_id = :topic_id AND
            NOT p.hidden AND
            v.post_id IS NULL AND
            p.updated_at > :min_date
      ORDER BY post_number
    SQL
    min_date =
      (
        if SiteSetting.minimum_review_date.present?
          Date.parse(SiteSetting.minimum_review_date)
        else
          Date.parse("1970-01-01")
        end
      )

    DB.query_single(sql, min_date: min_date, topic_id: object.topic.id)
  end

  add_to_serializer(
    :topic_list_item,
    :requires_review,
    include_condition: -> { scope.is_moderator? && object.requires_review },
  ) { object.requires_review }
end
