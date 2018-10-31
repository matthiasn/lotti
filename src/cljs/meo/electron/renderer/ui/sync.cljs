(ns meo.electron.renderer.ui.sync
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [reagent.core :as rc]
            [taoensso.timbre :refer-macros [info error]]
            [matthiasn.systems-toolbox.component :as stc]
            [clojure.pprint :as pp]))

(defn input [t v cb]
  [:input {:value     v
           :type      t
           :on-change cb}])

(defn set-local [local path ev]
  (swap! local assoc-in path (-> ev .-nativeEvent .-target .-value)))

(defn settings-item [local t path label visible]
  (let [input-cb #(partial set-local local path)]
    [:tr {:class (when-not visible "invisible")}
     [:td label]
     [:td [input t (get-in @local path) (input-cb)]]]))

(def defaults {:authTimeout 15000
               :connTimeout 30000
               :port        993
               :autotls     true
               :tls         true})

(defn sync [put-fn]
  (let [iww-host (.-iwwHOST js/window)
        imap-status (subscribe [:imap-status])
        imap-cfg (subscribe [:imap-cfg])
        local (rc/atom (or @imap-cfg {}))
        save (fn [_] (info "save") (put-fn [:imap/save-cfg @local]))]
    (fn config-render [put-fn]
      (let [connected (= (:status @imap-status) :read-mailboxes)
            verify-account #(put-fn [:imap/get-status @local])]
        [:div.sync-cfg
         [:div.settings
          [:table
           [:tbody
            [settings-item local :text [:server :host] "Host:" true]
            [settings-item local :number [:server :port] "Port:" true]
            [settings-item local :text [:server :user] "User:" true]
            [settings-item local :password [:server :password] "Password:" true]
            [:tr.btn-check
             [:td
              [:button {:on-click verify-account}
               "test account"]]
             (when (= :saved (:status @imap-status))
               [:td.success (:detail @imap-status) [:i.fas.fa-check]])
             (when connected
               [:td.success "connection successful" [:i.fas.fa-check]
                (when-not (= @local @imap-cfg)
                  [:button.save {:on-click save}
                   "save"])])
             (when (= :error (:status @imap-status))
               [:td.fail (:detail @imap-status) [:i.fas.fa-exclamation-triangle]])]
            [settings-item local :text [:sync :write :mailbox] "Write Mailbox:" connected]
            [settings-item local :password [:sync :write :secret] "Write Secret:" connected]
            [settings-item local :text [:sync :read :fred :mailbox] "Read Mailbox:" connected]
            [settings-item local :password [:sync :read :fred :secret] "Read Secret:" connected]]]]
         [:div
          [:img {:src (str "http://" iww-host "/secrets/"
                           (stc/make-uuid) "/secrets.png")}]]]))))
