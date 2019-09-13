(ns meins.electron.renderer.ui.config.sync
  (:require [moment]
            [meins.electron.renderer.ui.config.qr-scanner :as qrs]
            [meins.electron.renderer.ui.config.qr-gen :as qrg]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [reagent.core :as r]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
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

(defn sync []
  (let [iww-host (.-iwwHOST js/window)
        imap-status (subscribe [:imap-status])
        imap-cfg (subscribe [:imap-cfg])
        cfg (r/atom (or @imap-cfg {}))
        save (fn [_] (info "save") (emit [:imap/save-cfg @cfg]))]
    (fn config-render []
      (let [connected (= (:status @imap-status) :read-mailboxes)
            verify-account #(emit [:imap/get-status @cfg])
            create-key-pair #(emit [:crypto/create-keys])]
        [:div.sync-cfg
         [:div.settings
          [:h2 "Sync Settings"]
          [:table
           [:tbody
            [settings-item cfg :text [:server :host] "Host:" true]
            [settings-item cfg :number [:server :port] "Port:" true]
            [settings-item cfg :text [:server :user] "User:" true]
            [settings-item cfg :password [:server :password] "Password:" true]
            [:tr.btn-check
             [:td
              [:button {:on-click verify-account}
               "test account"]]
             (when (= :saved (:status @imap-status))
               [:td.success (:detail @imap-status) [:i.fas.fa-check]])
             (when connected
               [:td.success "connection successful" [:i.fas.fa-check]
                (when-not (= @cfg @imap-cfg)
                  [:button.save {:on-click save}
                   "save"])])
             (when (= :error (:status @imap-status))
               [:td.fail (:detail @imap-status) [:i.fas.fa-exclamation-triangle]])]
            [settings-item cfg :text [:sync :write :mailbox] "Write Mailbox:" connected]
            [settings-item cfg :password [:sync :write :secret] "Write Secret:" connected]
            [settings-item cfg :text [:sync :read :fred :mailbox] "Read Mailbox:" connected]
            [settings-item cfg :password [:sync :read :fred :secret] "Read Secret:" connected]]]
          [:button {:on-click create-key-pair}
           "(Re-)Create Key Pair"]]
         [:div
          ;[:img {:src (str "http://" iww-host "/secrets/" (stc/make-uuid) "/secrets.png")}]
          [qrg/qr-code-gen cfg connected]
          [qrs/scanner cfg]]]))))
