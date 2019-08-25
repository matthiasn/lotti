(ns meins.electron.renderer.ui.config.qr-scanner
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [reagent.core :as r]
            ["@matthiasn/instascan" :as qr :refer [Camera Scanner]]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [taoensso.timbre :refer-macros [info error]]
            [matthiasn.systems-toolbox.component :as stc]
            [clojure.pprint :as pp]))

(defn stop-scanning [local]
  (.stop (:scanner @local)))

(defn did-mount [local _]
  (let [el (.getElementById js/document "qr-video")
        scanner (Scanner. (clj->js {:video el}))
        handler (fn [content img]
                  (js/console.info content)
                  (stop-scanning local))
        start-scanning (fn [cameras]
                         (when (pos? (.-length cameras))
                           (.start scanner (aget cameras 0))))]
    (swap! local assoc :scanner scanner)
    (.addListener scanner "scan" handler)
    (-> (.getCameras Camera)
        (.then start-scanning))
    (info "QR scanner did mount")))

(defn will-unmount [local _]
  (info "QR scanner will unmount")
  (stop-scanning local))

(defn scanner []
  (let [local (r/atom {})]
    (r/create-class
      {:component-did-mount    (partial did-mount local)
       :component-will-unmount (partial will-unmount local)
       :display-name           "QR-Scanner"
       :reagent-render         (fn [_] [:video#qr-video])})))
