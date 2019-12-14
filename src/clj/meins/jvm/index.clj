(ns meins.jvm.index
  (:require [compojure.core :refer [GET]]
            [compojure.route :as r]
            [hiccup.page :refer [html5]]
            [meins.jvm.file-utils :as fu]
            [meins.jvm.routes.map-tile :as mt]))

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
   mt/map-tile-route])

(def sente-map
  {:index-page-fn index-page
   :routes-fn     routes-fn
   :port          port
   :opts          {:in-chan    [:buffer 100]
                   :out-chan   [:buffer 100]
                   :reload-cmp false}
   :relay-types   #{:entry/saved :backend-cfg/new :cmd/toggle-key :cfg/show-qr
                    :ws/ping :startup/progress :file/encrypt :search/res :sync/imap
                    :sync/start-imap :gql/res :gql/res2 :metrics/info}})
