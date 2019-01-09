(ns meins.jvm.routes.upload-qr
  "Functions for rendering a QR code that contains the IP address for upload."
  (:require [compojure.core :refer [GET]]
            [clj.qrgen :as qr]
            [taoensso.timbre :refer [info error debug]]
            [matthiasn.systems-toolbox.component :as st]
            [meins.jvm.file-utils :as fu]))

(def secrets-route
  (GET "/secrets/:uuid/secrets.png" [_uuid]
    (qr/as-input-stream
      (let [secrets (str (fu/read-secrets))]
        (debug "QR Code for:" secrets)
        (qr/from secrets :size [400 400])))))
