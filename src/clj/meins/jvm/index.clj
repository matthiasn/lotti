(ns meins.jvm.index
  (:require [hiccup.page :refer [html5 include-css include-js]]
            [compojure.route :as r]
            [compojure.core :refer [GET]]
            [meins.jvm.routes.upload-qr :as qr]
            [meins.jvm.routes.help :as h]
            [meins.jvm.routes.map-tile :as mt]
            [meins.jvm.file-utils :as fu]))

(defn index-page [_]
  (html5
    {:lang "en"}
    [:head [:title "test"]]
    [:body "hello world..."]))

(def port 8765)
(def package-json (slurp (str fu/app-path "/package.json")))

(defn routes-fn [_put-fn]
  [(r/files "/audio" {:root (str fu/data-path "/audio/")})
   (GET "/package.json" [] package-json)
   qr/secrets-route
   mt/map-tile-route
   h/help-img-route
   h/help-route])

(def sente-map
  {:index-page-fn index-page
   :routes-fn     routes-fn
   :port          port
   :opts          {:in-chan  [:buffer 100]
                   :out-chan [:buffer 100]}
   :relay-types   #{:entry/saved :backend-cfg/new :cmd/toggle-key :cfg/show-qr
                    :ws/ping :startup/progress :file/encrypt :search/res :sync/imap
                    :sync/start-imap :gql/res :metrics/info}})
