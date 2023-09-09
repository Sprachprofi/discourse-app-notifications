# frozen_string_literal: true

require "net/https"

module DiscourseAppNotifications
  class Pusher
    def self.push(user, payload)
      message = {
        title: I18n.t(
          "discourse_app_notifications.popup.#{Notification.types[payload[:notification_type]]}",
          site_title: SiteSetting.title,
          topic: payload[:topic_title],
          username: payload[:username]
        ),
        message: payload[:excerpt],
        url: "#{Discourse.base_url}/#{payload[:post_url]}"
      }
      self.send_notification(user, message)
    end

    def self.confirm_subscribe(user)
      message = {
        title: I18n.t(
          "discourse_app_notifications.confirm_title",
          site_title: SiteSetting.title,
        ),
        message: I18n.t("discourse_app_notifications.confirm_body"),
        url: "#{Discourse.base_url}"
      }
      self.send_notification(user, message)
    end

    def self.subscribe(user, subscription)
      user.custom_fields[DiscourseAppNotifications::PLUGIN_NAME] = subscription
      user.save_custom_fields(true)
    end

    def self.unsubscribe(user)
      user.custom_fields.delete(DiscourseAppNotifications::PLUGIN_NAME)
      user.save_custom_fields(true)
    end

    private

    def self.send_notification(user, message_hash)
      filename = "gcp_key.json"
      if !File.exists?(filename) and SiteSetting.app_notifications_google_json
        File.open(filename, 'w') { |file| file.write(SiteSetting.app_notifications_google_json) }
      end
      raise "Error: Missing google json for push notifications" unless File.exists?(filename)
      
		  fcm = FCM.new(SiteSetting.app_notifications_api_key, filename, SiteSetting.app_notifications_project_id)

      message = {
        'token': user.custom_fields[DiscourseAppNotifications::PLUGIN_NAME],
        'data': {
          "linked_obj_type" => 'link',
          "linked_obj_data" => message_hash[:url],
        },
        'notification': {
          title: message_hash[:title],
          body: message_hash[:message],
        },
        'android': {
          "priority": "normal",
        },
        'apns': {
          headers:{
            "apns-priority":"5"
          },
          payload: {
            aps: {
              "category": "#{Time.zone.now.to_i}",
              "sound": "default",
              "interruption-level": "active"
            }
          },
        },
        'fcm_options': {
          "analytics_label": "Label"
        }
      }

      response = fcm.send_v1(message)
      if response[:response] == 'success'
        return true
      else
        if response[:status_code] == 400
          Rails.logger.error "ERROR: push notification was malformed. " + response[:body].to_s
        elsif response[:status_code] == 404
          self.unsubscribe user
        else 
          Rails.logger.error "ERROR: something was wrong with the push notification, code #{response[:status_code]}. Body: " + response[:body].to_s
        end
        return false
      end      
    end

  end
end
