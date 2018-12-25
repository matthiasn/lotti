(ns meo.electron.renderer.ui.re-frame.db
  (:require [reagent.core :as rc]
            [taoensso.timbre :refer [info error debug]]))

; to be overwritten with put-fn on ui startup
(def emit-atom (atom (fn [])))
(defn emit [m] (@emit-atom m))
