import { ajax } from "discourse/lib/ajax";

export function subscribe(subscription) {
  return ajax("/app_notifications/subscribe", {
    type: "POST",
    data: { subscription: subscription }
  });
}

export function unsubscribe() {
  return ajax("/app_notifications/unsubscribe", {
    type: "POST"
  });
}
