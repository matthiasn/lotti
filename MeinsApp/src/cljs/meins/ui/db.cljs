(ns meins.ui.db
  (:require [re-frame.core :refer [reg-sub]]))

; to be overwritten with put-fn on ui startup
(def emit-atom (atom (fn [])))
(defn emit [m] (@emit-atom m))

;(reg-sub :active-theme (fn [db _] (:active-theme db)))
(reg-sub :active-theme (fn [db _] :dark))
(reg-sub :all-timestamps (fn [db _] (:all-timestamps db)))
