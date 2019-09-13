(ns meins.electron.renderer.ui.config.qr-gen
  (:require [reagent.core :as r]
            ["@zxing/library" :refer [BrowserQRCodeSvgWriter]]
            [meins.shared.encryption :as mse]
            [re-frame.core :refer [subscribe]]
            [meins.electron.main.crypto :as kc]
            [taoensso.timbre :refer-macros [info error]]))

(defn qr-code [s]
  (r/create-class
    {:component-did-mount (fn [_]
                            (let [qr-writer (BrowserQRCodeSvgWriter.)]
                              (.writeToDom qr-writer "#sync-cfg-qr" s 400 400)
                              (info "QR-Code generated.")))
     :display-name        "QR-Generator"
     :reagent-render      (fn [_]
                            [:div#sync-cfg-qr])}))

(defn qr-code-gen
  [cfg-atom _]
  (let [data (dissoc @cfg-atom :mobile :sync)
        crypto-cfg (subscribe [:crypto-cfg])
        s (pr-str data)]
    (fn [_ show]
      (let [my-secret-key (some->  @crypto-cfg :secretKey mse/hex->array)
            their-public-key (some-> @cfg-atom :mobile :public-key mse/hex->array)]
        (when (and my-secret-key their-public-key show)
          [:div
           [qr-code (mse/encrypt-asymm s their-public-key my-secret-key)]])))))