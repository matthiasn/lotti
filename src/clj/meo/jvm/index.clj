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
   :opts          {:in-chan  [:buffer 100]
                   :out-chan [:buffer 100]}
   :relay-types   #{:entry/saved :backend-cfg/new :cmd/toggle-key :cfg/show-qr
                    :ws/ping :startup/progress :file/encrypt :search/res :gql/res}})
