(ns meins.electron.renderer.ui.preferences.qr-scanner
  (:require ["@zxing/library" :refer [BrowserQRCodeReader]]
            [cljs.tools.reader.edn :as edn]
            [clojure.pprint :as pp]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [reagent.core :as r]
            [taoensso.timbre :refer [error info]]))

(defn stop-scanning [local]
  (let [qr-reader (:qr-reader @local)]
    (some-> qr-reader
            (.-stream)
            (.getTracks)
            (aget 0)
            (.stop))
    (.stopAsyncDecode qr-reader)))

(defn did-mount [local cfg _]
  (let [qr-reader (BrowserQRCodeReader.)
        on-scanned (fn [qr]
                     (try
                       (let [data (edn/read-string (.-text qr))]
                         (info "Scanned data:" data)
                         (emit [:imap/save-cfg (merge @cfg {:mobile data})])
                         (stop-scanning local)
                         (swap! local assoc :page :show-qr))
                       (catch :default e (error e))))
        scan (fn [cameras]
               (when (pos? (.-length cameras))
                 (let [cam-id (aget cameras 0 "deviceId")]
                   (-> qr-reader
                       (.decodeFromInputVideoDevice cam-id "qr-video")
                       (.then on-scanned)
                       (.catch #(js/console.error %))))))]
    (swap! local assoc :qr-reader qr-reader)
    (js/console.info qr-reader)
    (-> (.listVideoInputDevices qr-reader)
        (.then scan))
    (info "QR scanner did mount")))

(defn qr-render [_]
  [:div [:video#qr-video]])

(defn will-unmount [local _]
  (info "QR scanner will unmount")
  (stop-scanning local))

(defn scanner [local cfg]
  (swap! local assoc :scanned false)
  (r/create-class
    {:component-did-mount    (partial did-mount local cfg)
     :component-will-unmount (partial will-unmount local)
     :display-name           "QR-Scanner"
     :reagent-render         qr-render}))
