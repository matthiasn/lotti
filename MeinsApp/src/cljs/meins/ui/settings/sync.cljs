(ns meins.ui.settings.sync
  (:require ["react-navigation-stack" :refer [createStackNavigator]]
            [cljs.tools.reader.edn :as edn]
            [meins.shared.encryption :as mse]
            [meins.ui.db :refer [emit]]
            [meins.ui.elements.qr :as qr]
            [meins.ui.settings.items :refer [item screen switch-item button] :as items]
            [meins.ui.shared :refer [alert cam scroll settings-list settings-list-item status-bar text view]]
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
        our-secret-key (:secretKey (:key-pair @local))
        decrypted (mse/decrypt-asymm ciphertext their-public-key our-secret-key)
        cfg (merge (edn/read-string decrypted)
                   {:desktop {:publicKey their-public-key}})]
    (emit [:secrets/set cfg])
    (cb)))

(defn settings-page [& args]
  (let [theme (subscribe [:active-theme])]
    (fn [& args]
      (let [bg (get-in styles/colors [:list-bg @theme])]
        [view {:style {:display          :flex
                       :flex-direction   :column
                       :padding-top      10
                       :background-color bg
                       :height           "100%"}}
         [status-bar {:barStyle "light-content"}]
         (into [view {:style {:display       :flex
                              :padding-left  24
                              :padding-right 24}}]
               args)]))))

(defn sync-settings [_]
  (let [cfg (subscribe [:cfg])
        local (r/atom {:show-qr false})
        toggle-enable #(emit [:cfg/set {:sync-active (not (:sync-active @cfg))}])]
    (kc/get-keypair #(swap! local assoc :key-pair %))
    (fn [{:keys [navigation]}]
      (let [{:keys [navigate]} (js->clj navigation :keywordize-keys true)]
        [settings-page
         [switch-item {:label     "ENABLE SYNC"
                       :on-toggle toggle-enable
                       :value     (:sync-active @cfg)}]
         [item {:label         "ASSISTANT"
                :has-nav-arrow true
                :on-press      #(navigate "sync-intro")}]
         (if (:key-pair @local)
           [item {:label    "DELETE KEYPAIR"
                  :on-press (fn [_]
                              (kc/del-keypair)
                              (swap! local assoc :key-pair nil))}]
           [item {:label    "GENERATE KEYPAIR"
                  :on-press #(set-keypair local)}])
         [item {:label    "RESET LAST READ"
                :on-press #(emit [:state/reset {:type :last-uid-read}])}]
         (when (and (:entry-pprint @cfg) (:key-pair @local))
           [text {:style {:font-size   8
                          :color       "#888"
                          :font-weight "100"
                          :flex        2
                          :margin      2
                          :text-align  "center"}}
            (str (:key-pair @local))])]))))

(defn settings-text [s]
  [text {:style {:font-size   12
                 :font-family :Montserrat-Regular
                 :text-align  :left
                 :opacity     0.68
                 :color       :white}}
   s])

(defn intro [_]
  (let [cfg (subscribe [:cfg])
        local (r/atom {:show-qr false})]
    (kc/get-keypair #(swap! local assoc :key-pair %))
    (fn [{:keys [navigation]}]
      (let [{:keys [navigate]} (js->clj navigation :keywordize-keys true)
            public-key (-> @local :key-pair :publicKey)]
        [settings-page
         [settings-text
          "Let's set up the communication with the desktop and start syncing. For that, we need a public/private key pair."]
         (if public-key
           [button {:label         "NEXT"
                    :has-nav-arrow true
                    :on-press      #(navigate "sync-show-qr")}]
           [button {:label         "GENERATE KEY PAIR"
                    :has-nav-arrow false
                    :on-press      #(set-keypair local)}])
         (when (:entry-pprint @cfg)
           (when-let [kp (:key-pair @local)]
             [text {:style {:font-size   8
                            :color       "#888"
                            :font-weight "100"
                            :flex        2
                            :margin      2
                            :padding-top 30
                            :text-align  "center"}}
              (str kp)]))]))))

(defn show-qr [_]
  (let [local (r/atom {:show-qr false})]
    (kc/get-keypair #(swap! local assoc :key-pair %))
    (fn [{:keys [navigation]}]
      (let [{:keys [navigate]} (js->clj navigation :keywordize-keys true)]
        [settings-page
         (when-let [public-key (-> @local :key-pair :publicKey)]
           [qr/qr-code public-key])
         [settings-text "Scan this code with your desktop webcam."]
         [button {:label         "DONE? NEXT"
                  :has-nav-arrow true
                  :on-press      #(navigate "sync-scan-qr")}]]))))

(defn scan-qr [_]
  (let [local (r/atom {:show-qr false})]
    (kc/get-keypair #(swap! local assoc :key-pair %))
    (fn [{:keys [navigation]}]
      (let [{:keys [navigate]} (js->clj navigation :keywordize-keys true)
            on-read (partial on-barcode-read local #(navigate "sync-success"))]
        [settings-page
         [cam {:style         {:width         "100%"
                               :height        300
                               :margin-bottom 30
                               :padding-top   30}
               :onBarCodeRead on-read}]
         [settings-text "Scan the barcode shown on the desktop."]]))))

(defn success [_]
  (let []
    (fn [{:keys [navigation]}]
      (let [{:keys [navigate]} (js->clj navigation :keywordize-keys true)]
        [settings-page
         [settings-text "Congrats, all set up."]
         [button {:label         "FINISH"
                  :has-nav-arrow true
                  :on-press      #(navigate "sync")}]]))))
