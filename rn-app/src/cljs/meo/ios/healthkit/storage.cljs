(ns meo.ios.healthkit.storage
  (:require-macros [cljs.core.async.macros :refer [go]])
  (:require [glittershark.core-async-storage :as as]
            [cljs.core.async :refer [<!]]))


(defn set-async [k v]
  (let []
    (.info js/console k)
    (go (<! (as/set-item k v)))))


(defn get-async [k cb]
  (go (try
        (when-let [v (second (<! (as/get-item k)))]
          (cb v))
        (catch js/Object e
          (.error js/console e)))))