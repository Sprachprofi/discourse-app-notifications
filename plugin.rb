# frozen_string_literal: true

# name: discourse-app-notifications
# about: Plugin for integrating firebase notifications to a custom app
# version: 0.1.0
# authors: Judith Meyer, Jeff Wong (original plugin: discourse-pushover-notifications)
# url: https://github.com/sprachprofi/discourse-app-notifications

enabled_site_setting :app_notifications_enabled
gem 'googleauth', '1.7.0'
gem 'fcm', '1.0.8'

after_initialize do
  module ::DiscourseAppNotifications
    PLUGIN_NAME ||= 'discourse_app_notifications'.freeze

    autoload :Pusher, "#{Rails.root}/plugins/discourse-app-notifications/services/discourse_app_notifications/pusher"

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseAppNotifications
    end
  end

  User.register_custom_field_type(DiscourseAppNotifications::PLUGIN_NAME, :json)
  allow_staff_user_custom_field DiscourseAppNotifications::PLUGIN_NAME

  DiscourseAppNotifications::Engine.routes.draw do
    post '/subscribe' => 'push#subscribe'
    post '/unsubscribe' => 'push#unsubscribe'
  end

  Discourse::Application.routes.append do
    mount ::DiscourseAppNotifications::Engine, at: '/app_notifications'
  end

  require_dependency 'application_controller'
  class DiscourseAppNotifications::PushController < ::ApplicationController
    requires_plugin DiscourseAppNotifications::PLUGIN_NAME

    layout false
    before_action :ensure_logged_in
    skip_before_action :preload_json

    def subscribe
      DiscourseAppNotifications::Pusher.subscribe(current_user, push_params)
      if DiscourseAppNotifications::Pusher.confirm_subscribe(current_user)
        render json: success_json
      else
        render json: { failed: 'FAILED', error: I18n.t("discourse_app_notifications.subscribe_error") }
      end
    end

    def unsubscribe
      DiscourseAppNotifications::Pusher.unsubscribe(current_user)
      render json: success_json
    end

    private

    def push_params
      params.require(:subscription)
    end
  end

  DiscourseEvent.on(:post_notification_alert) do |user, payload|
    if SiteSetting.app_notifications_enabled?
      Jobs.enqueue(:send_app_notifications, user_id: user.id, payload: payload)
    end
  end

  #DiscourseEvent.on(:user_logged_out) do |user|
  #  if SiteSetting.app_notifications_enabled?
  #    DiscourseAppNotifications::Pusher.unsubscribe(user)
  #    user.save_custom_fields(true)
  #  end
  #end

  require_dependency 'jobs/base'
  module ::Jobs
    class SendAppNotifications < ::Jobs::Base
      def execute(args)
        return unless SiteSetting.app_notifications_enabled?

        user = User.find(args[:user_id])
        DiscourseAppNotifications::Pusher.push(user, args[:payload])
      end
    end
  end
end
