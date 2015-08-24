// used in topic list
import TopicStatus from 'discourse/views/topic-status';

// used in topic (TODO centralize this)
import TopicStatusComponent from 'discourse/components/topic-status';

import TopicController from 'discourse/controllers/topic';

export default {
  name: 'extend-for-moderator-attention',
  initialize: function() {

    if (!Discourse.User.currentProp("moderator")) { return; }

    TopicController.reopen({
      readPosts(topicId, postNumbers) {
        var topic = this.get('model.postStream.topic');
        if (topic && topic.get('id') === topicId) {
          var unreviewed = topic.get('unreviewed_post_numbers');
          if (unreviewed) {
            postNumbers.forEach(function(num){
              unreviewed.removeObject(num);
            });
          }
        }
        this._super(topicId, postNumbers);
      }
    });

    TopicStatusComponent.reopen({

      unreviewedChanged: function(){
        var unreviewed = this.get('topic.unreviewed_post_numbers');
        if (!unreviewed) {
          return;
        }

        if (unreviewed.length === 0) {
          this.rerender();
        } else {
          // ninja in url so it does not flash on rerender
          this.$('.unreviewed')[0].href = this.get('topic.url') + "/" + unreviewed[0];
        }
      }.observes('topic.unreviewed_post_numbers.[]'),

      renderString: function(buffer){
        var posts = this.get('topic.unreviewed_post_numbers');
        if (posts && posts.length > 0) {
          var title = Handlebars.Utils.escapeExpression(I18n.t('mod_attention.requires_review'));
          var url = this.get('topic.url') + "/" + posts[0];
          buffer.push("<a href='" + url + "' title='" + title  +"' class='topic-status unreviewed'><i class='fa fa-asterisk'></i></a>");
        }
        this._super();
      }
    });

    TopicStatus.reopen({
      statuses: function(){
        var results = this._super();
        if (this.topic.requires_review) {
          results.push({
            openTag: 'a href',
            closeTag: 'a',
            title: I18n.t('mod_attention.requires_review'),
            icon: 'asterisk',
            href: this.get('topic.url') + "/" + this.get('topic.requires_review')
          });
        }
        return results;
      }.property()
    });
  }
}
