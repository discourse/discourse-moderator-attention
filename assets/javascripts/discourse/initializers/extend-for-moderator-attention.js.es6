import { default as computed, observes } from 'ember-addons/ember-computed-decorators';
import { iconHTML } from 'discourse/helpers/fa-icon';

export default {
  name: 'extend-for-moderator-attention',
  initialize(container) {

    const currentUser = container.lookup('current-user:main');
    if (!currentUser || !currentUser.get('moderator')) { return; }

    const TopicController = container.lookupFactory('controller:topic');
    TopicController.reopen({
      readPosts(topicId, postNumbers) {
        const topic = this.get('model.postStream.topic');
        if (topic && topic.get('id') === topicId) {
          const unreviewed = topic.get('unreviewed_post_numbers');
          if (unreviewed) {
            unreviewed.removeObjects(postNumbers);
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
        if (posts && posts.length > 0) {
          const title = Handlebars.Utils.escapeExpression(I18n.t('mod_attention.requires_review'));
          const url = this.get('topic.url') + "/" + posts[0];
          buffer.push(`<a href='${url}' title='${title}' class='topic-status unreviewed'>${icon}</a>`);
        }
        this._super(buffer);
      }
    });

    const TopicStatusView = container.lookupFactory('view:topic-status');
    TopicStatusView.reopen({
      @computed('topic.requires_review', 'topic.url')
      statuses(requiresReview, topicUrl) {
        const results = this._super();
        if (requiresReview) {
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
  }
}
