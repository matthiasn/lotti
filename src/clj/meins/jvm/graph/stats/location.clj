(ns meins.jvm.graph.stats.location
  "Get stats from graph."
  (:require [meins.jvm.graph.query :as gq]
            [ubergraph.core :as uc]))

#_
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
                         countries)]
    {:days-per-country  (into {} per-country)}))
