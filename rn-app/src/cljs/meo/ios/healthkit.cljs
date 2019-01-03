(ns meo.ios.healthkit
  (:require [clojure.pprint :as pp]
            [meo.utils.misc :as um]
            [meo.helpers :as h]
            [meo.ios.healthkit.bp :as hb]
            [meo.ios.healthkit.weight :as hw]
            [meo.ios.healthkit.energy :as he]
            [meo.ios.healthkit.exercise :as hx]
            [meo.ios.healthkit.steps :as hst]
            [meo.ios.healthkit.sleep :as hsl]
            [matthiasn.systems-toolbox.component :as st]))

(enable-console-print!)

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:healthkit/weight   hw/get-weight
                 :healthkit/steps    hst/get-steps
                 :healthkit/sleep    hsl/get-sleep-samples
                 :healthkit/bp       hb/blood-pressure
                 :healthkit/energy   he/get-energy
                 :healthkit/exercise hx/get-exercise
                 :healthkit/hrv      hb/heart-rate-variability}})
