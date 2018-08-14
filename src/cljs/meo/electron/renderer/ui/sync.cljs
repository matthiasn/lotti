(ns meo.electron.renderer.ui.sync
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [reagent.core :as rc]
            [taoensso.timbre :refer-macros [info error]]
            [meo.electron.renderer.ui.stats :as stats]
            [meo.electron.renderer.ui.menu :as menu]
            [clojure.string :as s]
            [matthiasn.systems-toolbox.component :as stc]))

(defn input [t v cb]
  [:input {:value     v
           :type      t
           :on-change cb}])

(defn set-local [local path ev]
  (swap! local assoc-in path (-> ev .-nativeEvent .-target .-value)))

(defn settings-item [local t k label visible]
  (let [input-cb #(partial set-local local [k])]
    [:tr {:class (when-not visible "invisible")}
     [:td label]
     [:td [input t (k @local) (input-cb)]]]))

(def defaults {:authTimeout 15000
               :connTimeout 30000
               :port        993
               :autotls     true
               :tls         true})

(defn sync [put-fn]
  (let [iww-host (.-iwwHOST js/window)
        local (rc/atom defaults)
        imap-status (subscribe [:imap-status])]
    (fn config-render [put-fn]
      (let [connected (= (:status @imap-status) :read-mailboxes)
            verify-account #(put-fn [:imap/get-status {:server @local}])]
        [:div.flex-container
         [:div.grid
          [:div.wrapper
           [menu/menu-view put-fn]
           [:div.sync-cfg
            [:div.settings
             [:table
              [:tbody
               [settings-item local :text :host "Host:" true]
               [settings-item local :number :port "Port:" true]
               [settings-item local :text :user "User:" true]
               [settings-item local :password :password "Password:" true]
               [:tr.btn-check
                [:td
                 [:button {:on-click verify-account}
                  "verify account"]]
                (when connected
                  [:td.success "connection successful" [:i.fas.fa-check]])
                (when (= :error (:status @imap-status))
                  [:td.fail (:detail @imap-status) [:i.fas.fa-exclamation-triangle]])]
               [settings-item local :text :write-mailbox "Write Mailbox:" connected]
               [settings-item local :password :write-secret "Write Secret:" connected]
               [settings-item local :text :read-mailbox "Read Mailbox:" connected]
               [settings-item local :password :read-secret "Read Secret:" connected]]]]
            [:div
             [:img {:src (str "http://" iww-host "/secrets/"
                              (stc/make-uuid) "/secrets.png")}]]]]
          [:div.footer [stats/stats-text]]]]))))
