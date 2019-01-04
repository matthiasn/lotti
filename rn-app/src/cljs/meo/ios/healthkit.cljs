(ns meo.ios.healthkit
  (:require [meo.ios.healthkit.storage :as hs]
            [meo.ios.healthkit.bp :as hb]
            [meo.ios.healthkit.weight :as hw]
            [meo.ios.healthkit.energy :as he]
            [meo.ios.healthkit.exercise :as hx]
            [meo.ios.healthkit.steps :as hst]
            [meo.ios.healthkit.sleep :as hsl]
            [matthiasn.systems-toolbox.component :as st]))

(enable-console-print!)

(defn state-fn [put-fn]
  (let [state (atom {})]
    (add-watch state :watcher
               (fn [key atom old-state new-state]
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
