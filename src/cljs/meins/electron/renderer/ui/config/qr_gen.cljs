(ns meins.electron.renderer.ui.config.qr-gen
  (:require [reagent.core :as r]
            ["@zxing/library" :refer [BrowserQRCodeSvgWriter]]
            [meins.shared.encryption :as mse]
            [re-frame.core :refer [subscribe]]
            [taoensso.timbre :refer-macros [info error]]
            [meins.common.utils.misc :as u]))

(defn qr-code [s]
  (r/create-class
    {:component-did-mount (fn [_]
                            (let [qr-writer (BrowserQRCodeSvgWriter.)]
                              (.writeToDom qr-writer "#sync-cfg-qr" s 500 500)
                              (info "QR-Code generated.")))
     :display-name        "QR-Generator"
     :reagent-render      (fn [_]
                            [:div#sync-cfg-qr])}))

(defn qr-code-gen
  [cfg-atom _]
  (let [crypto-cfg (subscribe [:crypto-cfg])]
    (fn [_ show]
      (let [data (u/imap-to-app-cfg @cfg-atom)
            s (pr-str data)
            our-secret-key (some-> @crypto-cfg :secretKey)
            their-public-key (some-> @cfg-atom :mobile :publicKey)]
        (when (and our-secret-key their-public-key show)
          (let [cfg-ciphertext (mse/encrypt-asymm s their-public-key our-secret-key)
                qr-data {:cfg       cfg-ciphertext
                         :publicKey our-secret-key}]
            [:div
             [qr-code (pr-str qr-data)]]))))))
