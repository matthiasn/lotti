(ns meo.electron.renderer.tensorflow
  "Adapted from example on https://js.tensorflow.org/"
  (:require [taoensso.timbre :refer-macros [info debug]]
            [meo.electron.renderer.helpers :as h]
            ["@tensorflow/tfjs" :as tf]
            [matthiasn.systems-toolbox.component :as st]))

(def dense-layer (aget tf "layers" "dense"))
(def simple-rnn (aget tf "layers" "simpleRNN"))

(defn tensor-2d [x y]
  (.tensor2d tf (clj->js x) (clj->js y)))

(defn state-fn [put-fn]
  (let [state (atom {})
        model (.sequential tf)
        _ (.add model (dense-layer (clj->js {:units 1 :inputShape [1]})))
        _ (.compile model (clj->js {:loss "meanSquaredError" :optimizer "sgd"}))
        xs (tensor-2d [1 2.1 3 4] [4 1])
        ys (tensor-2d [1 3 5 7] [4 1])]
    (-> (.fit model xs ys)
        (.then (fn []
                 (let [p (tensor-2d [5] [1 1])]
                   (.print (.predict model p))))))
    (.log js/console tf)
    {:state state}))

(defn cmp-map [cmp-id]
  (info "starting TensorFlow.js component")
  {:cmp-id      cmp-id
   :state-fn    state-fn
   :handler-map {}})
