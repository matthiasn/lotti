(ns meins.components.healthkit.storage
  (:require-macros [cljs.core.async.macros :refer [go]])
  (:require [cljs.core.async :refer [<!]]
            [glittershark.core-async-storage :as as]))


(defn set-async [k v]
  (js/console.info k)
  (go (<! (as/set-item k v))))


(defn get-async [k cb]
  (go (try
        (when-let [v (second (<! (as/get-item k)))]
          (cb v))
        (catch js/Object e
          (js/console.error e)))))
