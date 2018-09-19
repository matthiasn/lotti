(ns meo.jvm.index
  (:require [hiccup.page :refer [html5 include-css include-js]]
            [compojure.route :as r]
            [meo.jvm.routes.upload-qr :as qr]
            [meo.jvm.routes.map-tile :as mt]
            [meo.jvm.file-utils :as fu]))

(defn index-page [_]
  (html5
    {:lang "en"}
    [:head [:title "test"]]
    [:body "hello world..."]))

(def port 8765)

(defn routes-fn [_put-fn]
  [(r/files "/audio" {:root (str fu/data-path "/audio/")})
   qr/address-route
   qr/ws-address-route
   qr/secrets-route
   mt/map-tile-route])

(def sente-map
  {:index-page-fn index-page
   :routes-fn     routes-fn
   :port          port
   :opts          {:in-chan  [:buffer 100]
                   :out-chan [:buffer 100]}
   :relay-types   #{:entry/saved :backend-cfg/new :cmd/toggle-key :cfg/show-qr
                    :ws/ping :startup/progress :file/encrypt :search/res :sync/imap
                    :sync/start-imap :gql/res :gql/res2}})
