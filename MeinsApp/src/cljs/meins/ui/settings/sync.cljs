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

(defn on-barcode-read [local f e]
  (let [qr-code (js->clj e)
        payload (get qr-code "data")
        data (edn/read-string payload)
        their-public-key (:publicKey data)
        ciphertext (:cfg data)
        our-secret-key (:secretKey (:key-pair @local))
        decrypted (mse/decrypt-asymm ciphertext their-public-key our-secret-key)
        cfg (merge (edn/read-string decrypted)
                   {:desktop {:publicKey their-public-key}})]
    (swap! local assoc-in [:barcode] cfg)
    (emit [:secrets/set cfg])
    (swap! local assoc-in [:cam] false)))

(defn sync-settings [_]
  (let [theme (subscribe [:active-theme])
        cfg (subscribe [:cfg])
        local (r/atom {:show-qr false})
        toggle-enable #(emit [:cfg/set {:sync-active (not (:sync-active @cfg))}])]
    (kc/get-keypair #(swap! local assoc :key-pair %))
    (fn [{:keys [navigation]}]
      (let [{:keys [navigate]} (js->clj navigation :keywordize-keys true)
            bg (get-in styles/colors [:list-bg @theme])
            item-bg (get-in styles/colors [:button-bg @theme])
            text-color (get-in styles/colors [:btn-text @theme])]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :background-color bg
                       :height           "100%"}}
         [status-bar {:barStyle "light-content"}]

         [view {:style {:display        :flex
                        :padding-left   24
                        :padding-right  24
                        :padding-bottom 24}}
          [switch-item {:label     "ENABLE SYNC"
                        :on-toggle toggle-enable
                        :value     (:sync-active @cfg)}]
          [item {:label         "ASSISTANT"
                 :has-nav-arrow true
                 :on-press      #(navigate "sync-intro")}]]

         [settings-list {:border-color bg
                         :width        "100%"
                         :margin-top   20}
          (if (:key-pair @local)
            [settings-list-item {:title            "Delete Keypair"
                                 :hasNavArrow      false
                                 :background-color item-bg
                                 :titleStyle       {:color text-color}
                                 :on-press         (fn [_]
                                                     (kc/del-keypair)
                                                     (swap! local assoc :key-pair nil))}]
            [settings-list-item {:title            "Generate Keypair"
                                 :hasNavArrow      false
                                 :background-color item-bg
                                 :titleStyle       {:color text-color}
                                 :on-press         #(set-keypair local)}])
          [settings-list-item {:title            "Show barcode"
                               :hasNavArrow      false
                               :background-color item-bg
                               :titleStyle       {:color text-color}
                               :on-press         #(swap! local update-in [:show-qr] not)}]
          [settings-list-item {:title            "Scan barcode"
                               :hasNavArrow      false
                               :background-color item-bg
                               :titleStyle       {:color text-color}
                               :on-press         #(swap! local update-in [:cam] not)}]
          [settings-list-item {:title            "Reset last read"
                               :hasNavArrow      false
                               :background-color item-bg
                               :titleStyle       {:color text-color}
                               :on-press         #(emit [:state/reset {:type :last-uid-read}])}]]
         (when (:cam @local)
           [cam {:style         {:width  "100%"
                                 :flex   5
                                 :height 300}
                 :onBarCodeRead (partial on-barcode-read local (fn []))}])
         (when-let [kp (:key-pair @local)]
           [text {:style {:font-size   8
                          :color       "#888"
                          :font-weight "100"
                          :flex        2
                          :margin      2
                          :text-align  "center"}}
            (str kp)])
         (when-let [barcode (:barcode @local)]
           [text {:style {:font-size   8
                          :color       "#888"
                          :font-weight "100"
                          :flex        2
                          :margin      2
                          :text-align  "center"}}
            (str barcode)])
         (when (:show-qr @local)
           [qr/qr-code (-> @local :key-pair :publicKey)])]))))

(defn settings-text [s]
  [text {:style {:font-size   12
                 :font-family :Montserrat-Regular
                 :text-align  :left
                 :opacity     0.68
                 :color       :white}}
   s])

(defn sync-page [& args]
  (let [theme (subscribe [:active-theme])]
    (fn [& args]
      (let [bg (get-in styles/colors [:list-bg @theme])]
        [view {:style {:flex-direction   "column"
                       :padding-top      10
                       :background-color bg
                       :height           "100%"}}
         [status-bar {:barStyle "light-content"}]
         (into [view {:style {:display       :flex
                              :padding-left  24
                              :padding-right 24}}]
               args)]))))

(defn intro [_]
  (let [cfg (subscribe [:cfg])
        local (r/atom {:show-qr false})]
    (kc/get-keypair #(swap! local assoc :key-pair %))
    (fn [{:keys [navigation]}]
      (let [{:keys [navigate]} (js->clj navigation :keywordize-keys true)
            public-key (-> @local :key-pair :publicKey)]
        [sync-page
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
        [sync-page
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
        [sync-page
         [cam {:style         {:width  "100%"
                               :height 300}
               :onBarCodeRead on-read}]
         [settings-text "Scan the barcode shown on the desktop."]
         [button {:label         "NEXT"
                  :has-nav-arrow true
                  :on-press      #(navigate "sync-success")}]]))))

(defn success [_]
  (let []
    (fn [{:keys [navigation]}]
      (let [{:keys [navigate]} (js->clj navigation :keywordize-keys true)]
        [sync-page
         [settings-text "Congrats, all set up."]
         [button {:label         "FINISH"
                  :has-nav-arrow true
                  :on-press      #(navigate "sync")}]]))))
