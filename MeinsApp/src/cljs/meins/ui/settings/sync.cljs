(ns meins.ui.settings.sync
  (:require [cljs.tools.reader.edn :as edn]
            [meins.shared.encryption :as mse]
            [meins.ui.db :refer [emit]]
            [meins.ui.elements.qr :as qr]
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

(defn on-barcode-read [local e]
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
    (fn [_props]
      (let [bg (get-in styles/colors [:list-bg @theme])
            item-bg (get-in styles/colors [:button-bg @theme])
            text-color (get-in styles/colors [:btn-text @theme])]
        [scroll {:style {:flex-direction   "column"
                         :padding-top      10
                         :background-color bg
                         :height           "100%"}}
         [status-bar {:barStyle "light-content"}]
         [settings-list {:border-color bg
                         :width        "100%"}
          [settings-list-item {:title               "Enable Sync"
                               :has-switch          true
                               :switchState         (:sync-active @cfg)
                               :switchOnValueChange toggle-enable
                               :hasNavArrow         false
                               :background-color    item-bg
                               :titleStyle          {:color text-color}}]
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
                 :onBarCodeRead (partial on-barcode-read local)}])
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
