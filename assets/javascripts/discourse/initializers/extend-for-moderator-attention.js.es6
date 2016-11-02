import { default as computed, observes } from 'ember-addons/ember-computed-decorators';
import { iconHTML } from 'discourse-common/helpers/fa-icon';
import { withPluginApi } from 'discourse/lib/plugin-api';

function oldPluginCode(container) {
  const PostView = container.lookupFactory('view:post');
  PostView.reopen({
    classNameBindings: ['post.requiresReview:requires-review']
  });
}

function initializeModeratorAttention(api) {
  api.decorateWidget('post:classNames', dec => {
    const post = dec.getModel();

    if (post.get('requiresReview')) {
      return ['requires-review'];
    }
  });
}

export default {
  name: 'extend-for-moderator-attention',
  initialize(container) {

    const currentUser = container.lookup('current-user:main');
    if (!currentUser || !currentUser.get('moderator')) { return; }

    const Post= container.lookupFactory('model:post');
    Post.reopen({
      @computed()
      requiresReview(){
        const unreviewed = this.get('topic.unreviewed_post_numbers');
        if (!unreviewed) { return; }

        // true for binary search
        return _.indexOf(unreviewed, this.get('post_number'), true) !== -1;
      }
    });

    const TopicController = container.lookupFactory('controller:topic');
    TopicController.reopen({
      readPosts(topicId, postNumbers) {
        const topic = this.get('model.postStream.topic');
        if (topic && topic.get('id') === topicId) {
          const unreviewed = topic.get('unreviewed_post_numbers');
          if (unreviewed) {
            const initial = unreviewed.length;
            unreviewed.removeObjects(postNumbers);
            topic.set('requires_review', unreviewed.length > 0);
            if (unreviewed.length === 0 && initial === 1) {
              topic.set('fully_reviewed', true);
            }
          }
        }
        this._super(topicId, postNumbers);
      }
    });

    // used in topic (TODO centralize this)
    const TopicStatusComponent = container.lookupFactory('component:topic-status');
    const icon = iconHTML('asterisk');
    TopicStatusComponent.reopen({

      @observes('topic.unreviewed_post_numbers.[]')
      unreviewedChanged() {
        const unreviewed = this.get('topic.unreviewed_post_numbers');
        if (!unreviewed) { return; }

        if (unreviewed.length === 0) {
          this.rerender();
        } else {
          // ninja in url so it does not flash on rerender
          this.$('.unreviewed')[0].href = this.get('topic.url') + "/" + unreviewed[0];
        }
      },

      renderString(buffer) {
        const posts = this.get('topic.unreviewed_post_numbers');
        const fullyReviewed = this.get('topic.fully_reviewed');

        if (fullyReviewed || (posts && posts.length > 0)) {
          const title = Handlebars.Utils.escapeExpression(I18n.t('mod_attention.requires_review'));
          const url = this.get('topic.url') + "/" + posts[0];
          var reviewedClass = fullyReviewed ? "reviewed" : "unreviewed";
          buffer.push(`<a href='${url}' title='${title}' class='topic-status ${reviewedClass}'>${icon}</a>`);
        }
        this._super(buffer);
      }
    });

    const TopicStatusView = container.lookupFactory('view:topic-status');
    TopicStatusView.reopen({
      @computed('topic.requires_review', 'topic.url')
      statuses(requiresReview, topicUrl, fullyReviewed) {
        const results = this._super();
        if (requiresReview || fullyReviewed) {
          results.push({
            openTag: 'a href',
            closeTag: 'a',
            title: I18n.t('mod_attention.requires_review'),
            icon: 'asterisk',
            href: `${topicUrl}/${requiresReview}`
          });
        }
        return results;
      }
    });

    withPluginApi('0.1', api => initializeModeratorAttention(api), { noApi: () => oldPluginCode(container) });
  }
}
