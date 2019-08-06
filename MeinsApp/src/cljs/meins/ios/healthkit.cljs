(ns meins.ios.healthkit
  (:require [meins.ios.healthkit.storage :as hs]
            [meins.ios.healthkit.bp :as hb]
            [meins.ios.healthkit.weight :as hw]
            [meins.ios.healthkit.energy :as he]
            [meins.ios.healthkit.exercise :as hx]
            [meins.ios.healthkit.steps :as hst]
            [meins.ios.healthkit.sleep :as hsl]))

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
