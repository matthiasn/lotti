(ns meo.jvm.location
  (:require [clojure.pprint :as pp]
            [clojure.tools.logging :as log]
            [clj-uuid :as uuid]
            [camel-snake-kebab.core :refer :all]
            [cheshire.core :as cc]
            [clojure.string :as s]
            [clj-http.client :as hc]
            [clj-time.coerce :as ctc]
            [clj-time.format :as ctf]
            [clj-time.core :as ct]))

(defn get-geoname [entry]
  (try
    (when (and (not (:geoname entry)) (not= (:geoname entry) :removed))
      (let [lat (:latitude entry)
            lon (:longitude entry)
            parser (fn [res] (cc/parse-string (:body res) #(keyword (->kebab-case %))))]
        (when (and lat lon)
          (let [res (hc/get (str "http://localhost:3003/geocode?latitude=" lat "&longitude=" lon))
                geoname (ffirst (parser res))]
            geoname))))
    (catch java.net.ConnectException e (log/error "could not connect to geonames service"))))

(defn enrich-geoname [entry]
  (let [geoname (get-geoname entry)]
    (if (and geoname (not (:geoname entry)))
      (let [country (:country-code geoname)
            serialized-geoname (with-out-str (pp/pprint geoname))
            relevant (-> geoname
                         (select-keys [:name :country-code :geo-name-id])
                         (assoc-in [:admin-1-name] (get-in geoname [:admin-1-code :name]))
                         (assoc-in [:admin-2-name] (get-in geoname [:admin-2-code :name]))
                         (assoc-in [:admin-3-name] (get-in geoname [:admin-3-code :name]))
                         (assoc-in [:admin-4-name] (get-in geoname [:admin-4-code :name])))]
        (assoc-in entry [:geoname] relevant))
      entry)))
