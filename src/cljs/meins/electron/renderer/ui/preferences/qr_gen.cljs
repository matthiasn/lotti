(ns meins.electron.renderer.ui.preferences.qr-gen
  (:require ["@zxing/library" :refer [BrowserQRCodeSvgWriter]]
            [cljs.pprint :as pp]
            [meins.common.utils.misc :as u]
            [meins.shared.encryption :as mse]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [taoensso.timbre :refer [error info]]))

(defn qr-code [s]
  (r/create-class
    {:component-did-mount (fn [_]
                            (let [qr-writer (BrowserQRCodeSvgWriter.)]
                              (.writeToDom qr-writer "#sync-cfg-qr" s 450 450)
                              (info "QR-Code generated.")))
     :display-name        "QR-Generator"
     :reagent-render      (fn [_]
                            [:div#sync-cfg-qr])}))

(defn qr-code-gen []
  (let [crypto-cfg (subscribe [:crypto-cfg])
        imap-cfg (subscribe [:imap-cfg])]
    (fn [_]
      (let [data (u/imap-to-app-cfg @imap-cfg)
            s (pr-str data)
            our-secret-key (some-> @crypto-cfg :secretKey)
            our-public-key (some-> @crypto-cfg :publicKey)
            their-public-key (some-> @imap-cfg :mobile :publicKey)]
        (info "qr-code-gen their-public-key" their-public-key)
        (info "qr-code-gen our-public-key" our-public-key)
        [:div
         ;[:pre {:style {:color :white}} [:code (with-out-str (pp/pprint @crypto-cfg))]]
         (if (and our-secret-key their-public-key)
           (let [cfg-ciphertext (mse/encrypt-asymm s their-public-key our-secret-key)
                 qr-data {:cfg       cfg-ciphertext
                          :publicKey our-public-key}]
             [:div
              ^{:key qr-data}
              [qr-code (pr-str qr-data)]])
           [:div "error"])]))))
