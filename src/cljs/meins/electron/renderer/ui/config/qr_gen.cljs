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
                              (.writeToDom qr-writer "#sync-cfg-qr" s 500 500)
                              (info "QR-Code generated.")))
     :display-name        "QR-Generator"
     :reagent-render      (fn [_]
                            [:div#sync-cfg-qr])}))

(defn imap-to-app-cfg [imap-cfg]
  (let [server-cfg (:server imap-cfg)
        write-folder (-> imap-cfg :sync :read first second :mailbox)
        read-folder (-> imap-cfg :sync :write :mailbox)]
    {:server {:hostname (:host server-cfg)
              :port     (:port server-cfg)
              :username (:user server-cfg)
              :password (:password server-cfg)}
     :sync   {:write {:folder write-folder}
              :read  {:folder read-folder}}}))

(defn qr-code-gen
  [cfg-atom _]
  (let [crypto-cfg (subscribe [:crypto-cfg])]
    (fn [_ show]
      (let [data (imap-to-app-cfg @cfg-atom)
            s (pr-str data)
            my-secret-key (some-> @crypto-cfg :secretKey mse/hex->array)
            my-public-key-hex (some-> @crypto-cfg :publicKey)
            their-public-key (some-> @cfg-atom :mobile :publicKey mse/hex->array)
            cfg-ciphertext (mse/encrypt-asymm s their-public-key my-secret-key)
            qr-data {:cfg       cfg-ciphertext
                     :publicKey my-public-key-hex}]
        (when (and my-secret-key their-public-key show)
          [:div
           [qr-code (pr-str qr-data)]])))))
