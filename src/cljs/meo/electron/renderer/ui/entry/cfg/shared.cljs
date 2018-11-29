(ns meo.electron.renderer.ui.entry.cfg.shared
  (:require [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer-macros [info error debug]]
            [meo.electron.renderer.helpers :as h]
            [moment]))

(defn input-row [entry cfg put-fn]
  (let [{:keys [label validate path xf error]} cfg
        v (get-in entry path)
        t (:type cfg)
        v (if (and v (= :time t)) (h/m-to-hh-mm v) v)
        on-change (fn [ev]
                    (let [xf (or xf (if (= :number t) js/parseFloat identity))
                          v (xf (h/target-val ev))
                          v (if (= :time t)
                              (.asMinutes (.duration moment v))
                              v)
                          updated (assoc-in entry path v)]
                      (put-fn [:entry/update-local updated])))
        valid? (if validate (validate v) true)]
    [:div.row
     [:label label]
     [:input (merge {:on-change on-change
                     :class     "time"
                     :value     v}
                    cfg)]
     (if error [:span.err error]
               (when-not valid?
                 [:span.err "Invalid input"]))]))
