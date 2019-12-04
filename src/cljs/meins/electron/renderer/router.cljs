(ns meins.electron.renderer.router
  (:require [goog.events]
            [secretary.core :as secretary :refer [defroute]])
  (:import [goog.history EventType Html5History]))

(defn page-id
  "Maps page paths to view keywords."
  [page]
  (case page
    "dashboards" :dashboards
    "config" :config
    "countries" :countries
    "heatmap" :heatmap
    "calendar" :calendar
    "correlation" :correlation
    "empty" :empty
    :main))

(defn state-fn
  "Starts router, which dispatches navigation messages when user navigates."
  [put-fn]
  (let [set-tab-widget (fn [p id]
                         (let [page (page-id p)]
                           (put-fn [:nav/to {:page page :id id}])))]
    (defroute "/:page/:id" [page id] (set-tab-widget page id))
    (defroute "/:page" [page] (set-tab-widget page nil))
    (defroute "/" [] (set-tab-widget :main nil))
    (let [prefix (str js/window.location.protocol "//" js/window.location.host)
          url-change-handler #(secretary/dispatch! (.-token %))
          h (doto (Html5History.)
              (.setPathPrefix prefix)
              (.setUseFragment true)
              (goog.events/listen EventType.NAVIGATE url-change-handler)
              (.setEnabled true))
          state (atom {:history h})]
      {:state state})))

(defn nav-handler
  "Navigate to tab specified in message."
  [{:keys [msg-payload]}]
  (let [tab (:tab msg-payload)
        title (->> {}
                   :tabs
                   (filter #(= (:id %) tab))
                   first
                   :title)
        widget (:expand msg-payload)
        target-url (str "/#/" title (when widget (str "/" (name widget))))]
    (aset js/window "location" target-url)
    {}))

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {:nav/route-to nav-handler}})
