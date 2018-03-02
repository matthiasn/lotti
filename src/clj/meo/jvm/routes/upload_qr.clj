(ns meo.jvm.routes.upload-qr
  "Functions for rendering a QR code that contains the IP address for upload."
  (:require [compojure.core :refer [GET]]
            [clj.qrgen :as qr]
            [meo.jvm.upload :as up]
            [taoensso.timbre :refer [info error debug]]
            [meo.jvm.net :as net]
            [matthiasn.systems-toolbox.component :as st]
            [meo.jvm.file-utils :as fu]))

(def address-route
  (GET "/upload-address/:uuid/qrcode.png" [_uuid]
    (qr/as-input-stream
      (let [ip (ffirst (net/ips))
            url (str "http://" ip ":" @up/upload-port "/upload/")]
        (info "QR Code for:" url)
        (qr/from url :size [300 300])))))

(def ws-address-route
  (GET "/ws-address/:uuid/qrcode.png" [_uuid]
    (qr/as-input-stream
      (let [ip (ffirst (net/ips))
            url (str ip ":" @up/sync-ws-port)
            data {:url    url
                  :shared (str (st/make-uuid))}]
        (info "QR Code for:" url)
        (qr/from (str data) :size [300 300])))))

(def secrets-route
  (GET "/secrets/:uuid/secrets.png" [_uuid]
    (qr/as-input-stream
      (let [secrets (str (fu/read-secrets))]
        (debug "QR Code for:" secrets)
        (qr/from secrets :size [400 400])))))
