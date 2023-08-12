import { default as discourseComputed } from "discourse-common/utils/decorators";


import {
  subscribe as subscribeAppNotification,
  unsubscribe as unsubscribeAppNotification
} from "discourse/plugins/discourse-app-notifications/discourse/lib/app-notifications";

export default Ember.Component.extend({
  @discourseComputed
  showAppNotification() {
    return this.siteSettings.app_notifications_enabled;
  },

  has_subscription: Ember.computed.empty("subscription"),
  disabled: Ember.computed.or("has_subscription", "loading"),
  loading: false,
  errorMessage: null,

  calculateSubscribed() {
    this.set(
      "appNotificationSubscribed",
      this.currentUser.custom_fields.discourse_app_notifications !=
        null
    );
  },

  appNotificationSubscribed: null,

  init() {
    this._super(...arguments);
    this.setProperties({
      appNotificationSubscribed:
        this.currentUser.custom_fields
          .discourse_app_notifications != null,
      errorMessage: null
    });
  },

  actions: {
    subscribe() {
      this.setProperties({
        loading: true,
        errorMessage: null
      });
      subscribeAppNotification(this.subscription)
        .then(response => {
          if (response.success) {
            this.currentUser.custom_fields.discourse_app_notifications = this.subscription;
            this.calculateSubscribed();
          } else {
            this.set("errorMessage", response.error);
          }
        })
        .finally(() => this.set("loading", false));
    },

    unsubscribe() {
      this.setProperties({
        loading: true,
        errorMessage: null
      });
      unsubscribeAppNotification()
        .then(response => {
          if (response.success) {
            this.currentUser.custom_fields.discourse_app_notifications = null;
            this.calculateSubscribed();
          } else {
            this.set("errorMessage", response.error);
          }
        })
        .finally(() => this.set("loading", false));
    }
  }
});
