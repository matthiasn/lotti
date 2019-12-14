(ns meins.jvm.graph.stats.location
  "Get stats from graph."
  (:require [ubergraph.core :as uc]))

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
