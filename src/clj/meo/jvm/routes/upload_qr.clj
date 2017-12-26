(ns meo.jvm.routes.upload-qr
  "Functions for rendering a QR code that contains the IP address for upload."
  (:require [compojure.core :refer [GET]]
            [clj.qrgen :as qr]
            [meo.jvm.upload :as up]
            [clojure.tools.logging :as log]
            [meo.jvm.net :as net]))

(def address-qr-route
  (GET "/upload-address/:uuid/qrcode.png" [_uuid]
    (qr/as-input-stream
      (let [ip (ffirst (net/ips))
            url (str "http://" ip ":" @up/upload-port "/upload/")]
        (log/info "QR Code for:" url)
        (qr/from url :size [300 300])))))

(def env-port (get (System/getenv) "PORT"))

(defn ws-address-qr-route [port]
  (GET "/ws-address/:uuid/qrcode.png" [_uuid]
    (qr/as-input-stream
      (let [ip (ffirst (net/ips))
            url (str "http://" ip ":" (or env-port port))]
        (log/info "QR Code for:" url)
        (qr/from url :size [300 300])))))
