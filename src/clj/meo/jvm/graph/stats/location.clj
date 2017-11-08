(ns meo.jvm.graph.stats.location
  "Get stats from graph."
  (:require [ubergraph.core :as uber]
            [meo.jvm.graph.query :as gq]
            [clj-time.core :as t]
            [meo.common.utils.misc :as u]
            [clj-time.format :as ctf]
            [clojure.tools.logging :as log]
            [ubergraph.core :as uc]
            [clojure.pprint :as pp]
            [clj-time.coerce :as ctc]
            [clj-time.core :as ct]))

(defn locations
  "Gathers information about places visited."
  [current-state]
  (let [g (:graph current-state)
        countries (map :dest (uc/find-edges g {:src :countries}))
        per-country (map (fn [c]
                           (let [days (->> (uc/find-edges g {:src c})
                                           (map :dest)
                                           (filter #(= (:type %) :timeline/day)))]
                             [(:country-code c) (count days)]))
                         countries)
        geonames (map :dest (uc/find-edges g {:src :geonames}))
        per-geoname (map (fn [gn]
                           (let [days (->> (uc/find-edges g {:src gn})
                                           (map :dest)
                                           (filter #(= (:type %) :timeline/day)))]
                             [{:name    (-> gn :geoname :name)
                               :country (-> gn :geoname :country-code)}
                              (count days)]))
                         geonames)]
    {:days-per-country  (into {} per-country)
     :days-per-location (into {} per-geoname)}))
