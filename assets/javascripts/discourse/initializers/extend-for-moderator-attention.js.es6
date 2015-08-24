import TopicStatus from 'discourse/views/topic-status';

export default {
  name: 'extend-for-moderator-attention',
  initialize: function() {
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
