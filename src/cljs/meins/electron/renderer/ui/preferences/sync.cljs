(ns meins.electron.renderer.ui.preferences.sync
  (:require [cljs.pprint :as pp]
            [meins.electron.renderer.ui.preferences.qr-gen :as qrg]
            [meins.electron.renderer.ui.preferences.qr-scanner :as qrs]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [taoensso.timbre :refer [error info]]))

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

(defn welcome [local]
  [:div.welcome.page
   [:div.nav
    [:div]
    [:button {:on-click #(swap! local assoc :page :server)}
     "Next"]]
   [:h1 "Sync Assistant"]
   [:p "Let's get the synchronization between this application and your mobile phone set up, shall we?"]
   [:p "Communication between meins on mobile and on the desktop happens without cloud-based services. Instead,
        each participant in the communication stores encrypted messages for the other in an IMAP folder, which
        the other then occasionally checks."]
   [:p "For the encryption, a method called Elliptic Curve Cryptography is used, where each participant
        generating both a public and a private key, shares the public key with the other participant,
        and stores the private key in the keychain."]])

(defn server [local]
  (let [imap-status (subscribe [:imap-status])
        imap-cfg (subscribe [:imap-cfg])
        cfg (r/atom (or @imap-cfg {:server  defaults
                                   :checked false}))
        save (fn [_]
               (info "save IMAP cfg")
               (emit [:imap/save-cfg @cfg])
               (swap! local assoc :page :key-pair))]
    (fn [local]
      (let [connected (= (:status @imap-status) :read-mailboxes)
            verify-account (fn [_]
                             (swap! cfg assoc :checked true)
                             (emit [:imap/get-status @cfg]))]
        [:div.settings.page
         [:div.nav
          [:button {:on-click #(swap! local assoc :page :welcome)}
           "Previous"]
          (when (and connected (:checked @cfg))
            [:button {:on-click save}
             "Create Folders & continue"])]
         [:h1 "IMAP Server Settings"]
         [:p "Please enter your server details?"]
         [:table
          [:tbody
           [settings-item cfg :text [:server :host] "Host:" true]
           [settings-item cfg :number [:server :port] "Port:" true]
           [settings-item cfg :text [:server :user] "User:" true]
           [settings-item cfg :password [:server :password] "Password:" true]
           [:tr.btn-check
            [:td
             [:button {:on-click verify-account}
              "Check connection"]]
            (when (= :saved (:status @imap-status))
              [:td.success (:detail @imap-status) [:i.fas.fa-check]])
            (when connected
              [:td.success "connection successful" [:i.fas.fa-check]])
            (when (= :error (:status @imap-status))
              [:td.fail (:detail @imap-status) [:i.fas.fa-exclamation-triangle]])]]]]))))

(defn key-pair [_local]
  (let [crypto-cfg (subscribe [:crypto-cfg])
        create-key-pair #(emit [:crypto/create-keys])]
    (fn [local]
      (let [our-secret-key (some-> @crypto-cfg :secretKey)
            our-public-key (some-> @crypto-cfg :publicKey)]
        [:div.page
         [:div.nav
          [:button {:on-click #(swap! local assoc :page :server)}
           "Previous"]
          [:button {:on-click #(swap! local assoc :page :scan-qr)}
           "Next: Scan mobile device QR code"]]
         [:h1 "Crypto Key Assistant"]
         [:p "IMAP folders were created successfully." [:i.fas.fa-check]]
         (if (and our-secret-key our-public-key)
           [:div
            [:p "Using existing public and private key pair." [:i.fas.fa-check]]
            [:div {:style {:margin-bottom 5
                           :margin-top    100}}
             [:button {:on-click create-key-pair}
              "Re-create Key Pair"]]]
           [:div
            [:p "Here, we need to create a public/private key pair."]
            [:div {:style {:margin-bottom 5}}
             [:button {:on-click create-key-pair}
              "Create Key Pair"]]])]))))

(defn scan-qr [_local]
  (let [imap-cfg (subscribe [:imap-cfg])
        cfg (r/atom (or @imap-cfg {}))]
    (fn [local]
      [:div.page
       [:div.nav
        [:button {:on-click #(swap! local assoc :page :key-pair)}
         "Previous"]]
       [:h1 "Hello App!"]
       [:div
        [qrs/scanner local cfg]
        [:p "Here, you scan the public key of your smartphone."]]])))

(defn show-qr [local]
  [:div.page
   [:div.nav
    [:button {:on-click #(swap! local assoc :page :scan-qr)}
     "Previous"]
    [:button {:on-click #(swap! local assoc :page :done)}
     "Finish"]]
   [:h1 "Hello App, here's the SYNC configuration"]
   [qrg/qr-code-gen]
   [:p "Scan this in meins on your smartphone."]])

(defn done [_local]
  [:div.page
   [:h1 "High Five, all set up!"]
   [:p "You may now close this assistant."]])

(defn sync []
  (let [imap-cfg (subscribe [:imap-cfg])
        local (r/atom {:page :welcome})]
    (fn config-render []
      (let [view (case (:page @local)
                   :server server
                   :key-pair key-pair
                   :scan-qr scan-qr
                   :show-qr show-qr
                   :done done
                   welcome)]
        (pp/pprint @imap-cfg)
        [:div.sync-cfg
         [:div.settings
          [view local]]]))))
