(ns meins.ui.db
  (:require [re-frame.core :refer [reg-sub]]))

(def realm-db (atom nil))

; to be overwritten with put-fn on ui startup
(def emit-atom (atom (fn [])))
(defn emit [m] (@emit-atom m))

;(reg-sub :active-theme (fn [db _] (:active-theme db)))
(reg-sub :active-theme (fn [db _] :dark))
(reg-sub :global-vclock (fn [db _] (:global-vclock db)))
