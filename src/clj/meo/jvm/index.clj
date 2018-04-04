(ns meo.jvm.index
  (:require [hiccup.page :refer [html5 include-css include-js]]
            [compojure.route :as r]
            [meo.jvm.routes.upload-qr :as qr]
            [meo.jvm.routes.images :as ir]
            [meo.jvm.routes.map-tile :as mt]
            [meo.jvm.file-utils :as fu]))

(defn index-page [_]
  (html5
    {:lang "en"}
    [:head [:title "test"]]
    [:body "hello world"]))

(def port 8765)

(defn routes-fn [_put-fn]
  [(r/files "/photos" {:root fu/img-path})
   (r/files "/audio" {:root (str fu/data-path "/audio/")})
   (r/files "/videos" {:root (str fu/data-path "/videos/")})
   qr/address-route
   qr/ws-address-route
   qr/secrets-route
   ir/img-resized-route
   mt/map-tile-route])

(def sente-map
  {:index-page-fn index-page
   :routes-fn     routes-fn
   :port          port
   :sente-opts    {:ws-kalive-ms 2000}
   :relay-types   #{:entry/saved :entry/found :state/new :backend-cfg/new
                    :stats/result :stats/result2 :state/stats-tags :cmd/toggle-key
                    :state/stats-tags2 :search/refresh :cfg/show-qr :ws/ping
                    :startup/progress :file/encrypt :search/res}})
