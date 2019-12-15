(ns meins.ui.settings.sync
  (:require [cljs.tools.reader.edn :as edn]
            [meins.shared.encryption :as mse]
            [meins.ui.db :refer [emit]]
            [meins.ui.elements.qr :as qr]
            [meins.ui.settings.items :refer [button item settings-page settings-text spacer-y
                                             switch-item sync-assistant-page]]
            [meins.ui.shared :refer [cam modal text view]]
            [meins.ui.styles :as styles]
            [meins.util.keychain :as kc]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]))

(defn set-keypair
  "Sets keypair in keychain and sends update message."
  [local]
  (let [kp (mse/gen-key-pair-hex)]
    (kc/set-keypair kp)
    (swap! local assoc :key-pair kp)
    (emit [:secrets/set-kp kp])))

(defn on-barcode-read [local cb e]
  (let [qr-code (js->clj e)
        payload (get qr-code "data")
        data (edn/read-string payload)
        their-public-key (:publicKey data)
        ciphertext (:cfg data)
        our-secret-key (:secretKey (:key-pair @local))]
    (when (and ciphertext their-public-key our-secret-key)
      (let [decrypted (mse/decrypt-asymm ciphertext their-public-key our-secret-key)
            cfg (merge (edn/read-string decrypted)
                       {:desktop {:publicKey their-public-key}})]
        (emit [:secrets/set cfg])
        (cb cfg)))))

(defn sync-settings [_]
  (let [cfg (subscribe [:cfg])
        toggle-enable #(emit [:cfg/set {:sync-active (not (:sync-active @cfg))}])]
    (fn [{:keys [navigation]}]
      (let [{:keys [navigate]} (js->clj navigation :keywordize-keys true)]
        [settings-page
         [switch-item {:label     "Enable Sync"
                       :on-toggle toggle-enable
                       :value     (:sync-active @cfg)}]
         [item {:label         "Assistant"
                :has-nav-arrow true
                :on-press      #(navigate "sync-intro")}]
         [item {:label            "Advanced"
                :has-nav-arrow    true
                :btm-border-width 0
                :on-press         #(navigate "sync-advanced")}]]))))

(defn sync-advanced [_]
  (let [cfg (subscribe [:cfg])
        local (r/atom {})]
    (kc/get-keypair #(swap! local assoc :key-pair %))
    (fn [_]
      (let [del-keypair (fn [_]
                          (kc/del-keypair)
                          (swap! local assoc :key-pair nil)
                          (swap! local dissoc :del-visible))]
        [settings-page
         (if (:key-pair @local)
           [item {:label    "Delete Keypair"
                  :on-press #(swap! local assoc :del-visible true)}]
           [item {:label    "Generate Keypair"
                  :on-press #(set-keypair local)}])
         [modal {:isVisible (:del-visible @local)}
          [view {:style {:width           "100%"
                         :border-radius   styles/border-radius
                         :backgroundColor "red"}}
           [text {:style {:font-size   30
                          :padding     20
                          :font-family :Montserrat-SemiBold
                          :color       :white
                          :text-align  :center}}
            "CAUTION: run Assistant again after deleting key pair."]
           [button {:label    "Delete Keypair"
                    :style    {:margin-top 20}
                    :on-press del-keypair}]
           [button {:label    "CANCEL"
                    :style    {:margin-top 0}
                    :on-press #(swap! local dissoc :del-visible)}]]]
         (when (and (:entry-pprint @cfg) (:key-pair @local))
           [text {:style {:font-size   8
                          :color       "#888"
                          :font-weight "100"
                          :flex        2
                          :margin      2
                          :text-align  :center}}
            (str (:key-pair @local))])]))))

(defn intro [_]
  (let [local (r/atom {})]
    (kc/get-keypair #(swap! local assoc :key-pair %))
    (fn [{:keys [navigation]}]
      (let [{:keys [navigate]} (js->clj navigation :keywordize-keys true)
            public-key (-> @local :key-pair :publicKey)]
        [sync-assistant-page
         [spacer-y 24]
         [settings-text
          "Let's set up the communication with the desktop and start syncing. For that, we need a public/private key pair."]
         (if public-key
           [button {:label    "NEXT"
                    :on-press #(navigate "sync-show-qr")}]
           [button {:label    "GENERATE KEY PAIR"
                    :on-press #(set-keypair local)}])]))))

(defn show-qr [_]
  (let [local (r/atom {})]
    (kc/get-keypair #(swap! local assoc :key-pair %))
    (fn [{:keys [navigation]}]
      (let [{:keys [navigate]} (js->clj navigation :keywordize-keys true)]
        [sync-assistant-page
         [spacer-y 24]
         (when-let [public-key (-> @local :key-pair :publicKey)]
           [qr/qr-code public-key])
         [settings-text "Scan this code with your desktop webcam."]
         [button {:label    "DONE? NEXT"
                  :on-press #(navigate "sync-scan-qr")}]]))))

(defn scan-qr [_]
  (let [local (r/atom {})
        cfg (subscribe [:cfg])]
    (kc/get-keypair #(swap! local assoc :key-pair %))
    (fn [{:keys [navigation]}]
      (let [{:keys [navigate]} (js->clj navigation :keywordize-keys true)
            on-read (partial on-barcode-read local #(do
                                                      (swap! local assoc :cfg %)
                                                      (navigate "sync-success")))]
        [sync-assistant-page
         [cam {:style         {:width         "100%"
                               :height        400
                               :margin-bottom 30
                               :padding-top   30}
               :onBarCodeRead on-read}]
         [settings-text "Scan the barcode shown on the desktop."]
         (when (:entry-pprint @cfg)
           [text {:style {:font-size   8
                          :color       "#888"
                          :font-weight "100"
                          :flex        2
                          :margin      2
                          :text-align  "center"}}
            (str @local)])]))))

(defn success
  [{:keys [navigation]}]
  (let [{:keys [navigate]} (js->clj navigation :keywordize-keys true)]
    [sync-assistant-page
     [spacer-y 24]
     [settings-text "Congrats, all set up."]
     [button {:label    "FINISH"
              :on-press #(navigate "sync")}]]))
