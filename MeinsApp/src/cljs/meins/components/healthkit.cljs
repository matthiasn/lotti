(ns meins.components.healthkit
  (:require [meins.components.healthkit.bp :as hb]
            [meins.components.healthkit.energy :as he]
            [meins.components.healthkit.exercise :as hx]
            [meins.components.healthkit.sleep :as hsl]
            [meins.components.healthkit.steps :as hst]
            [meins.components.healthkit.storage :as hs]
            [meins.components.healthkit.weight :as hw]))

(enable-console-print!)

(defn state-fn [_put-fn]
  (let [state (atom {})]
    (add-watch state :watcher
               (fn [_key _atom _old-state new-state]
                 (hs/set-async :healthkit new-state)))
    (hs/get-async :healthkit #(reset! state %))
    {:state state}))

(defn cmp-map [cmp-id]
  {:state-fn    state-fn
   :cmp-id      cmp-id
   :handler-map {:healthkit/weight   hw/get-weight
                 :healthkit/steps    hst/get-steps
                 :healthkit/sleep    hsl/get-sleep-samples
                 :healthkit/bp       hb/blood-pressure
                 :healthkit/energy   he/get-energy
                 :healthkit/exercise hx/get-exercise
                 :healthkit/hrv      hb/heart-rate-variability}})
