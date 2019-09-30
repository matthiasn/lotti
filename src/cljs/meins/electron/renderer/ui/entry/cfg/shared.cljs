(ns meins.electron.renderer.ui.entry.cfg.shared
  (:require [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [moment]
            [re-frame.core :refer [subscribe]]
            [reagent.ratom :refer-macros [reaction]]
            [taoensso.timbre :refer-macros [debug error info]]))

(defn input-row [entry cfg]
  (let [{:keys [label validate path xf error default]} cfg
        update-entry (fn [entry v]
                       (let [updated (assoc-in entry path v)]
                         (emit [:entry/update-local updated])))
        v (get-in entry path)
        t (:type cfg)
        v (if (and v (= :time t)) (h/m-to-hh-mm v) v)
        on-change (fn [ev]
                    (let [xf (or xf (if (contains? #{:number :switch} t)
                                      js/parseFloat
                                      identity))
                          v (xf (h/target-val ev))
                          v (if (= :time t)
                              (.asMinutes (.duration moment v))
                              v)
                          updated (assoc-in entry path v)]
                      (emit [:entry/update-local updated])))
        valid? (if validate (validate v) true)]
    (when (and default (not v))
      (update-entry entry default))
    [:div.row
     [:label label]
     [:input (merge {:on-change on-change
                     :class     "time"
                     :value     v}
                    cfg)]
     (if error [:span.err error]
               (when-not valid?
                 [:span.err "Invalid input"]))]))

(defn input-table-row [entry cfg]
  (let [{:keys [label validate path xf error default]} cfg
        update-entry (fn [entry v]
                       (let [updated (assoc-in entry path v)]
                         (emit [:entry/update-local updated])))
        v (get-in entry path)
        t (:type cfg)
        v (if (and v (= :time t)) (h/m-to-hh-mm v) v)
        on-change (fn [ev]
                    (let [xf (or xf (if (contains? #{:number :switch} t)
                                      js/parseFloat
                                      identity))
                          v (xf (h/target-val ev))
                          v (if (= :time t)
                              (.asMinutes (.duration moment v))
                              v)
                          updated (assoc-in entry path v)]
                      (emit [:entry/update-local updated])))
        valid? (if validate (validate v) true)]
    (when (and default (not v))
      (update-entry entry default))
    [:tr
     [:td [:label label]]
     [:td [:input (merge {:on-change on-change
                          :class     "time"
                          :value     v}
                         cfg)]]]))
