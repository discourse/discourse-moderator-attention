# frozen_string_literal: true

require "rails_helper"

describe "read time integration" do
  it "can track topic/timings" do
    admin = Fabricate(:moderator)
    post1 = create_post

    sign_in admin

    # twice, once for update, once for insert
    2.times do
      post(
        "/topics/timings.json",
        params: {
          topic_id: post1.topic_id,
          topic_time: 10,
          timings: {
            post1.post_number => 100,
          },
        },
      )

      expect(response.status).to eq(200)

      count = DB.query_single(<<~SQL, user_id: admin.id, post_id: post1.id).first
        SELECT COUNT(*)
        FROM moderator_post_views
        WHERE post_id = :post_id AND user_id = :user_id
      SQL

      expect(count).to eq(1)
    end
  end
end
