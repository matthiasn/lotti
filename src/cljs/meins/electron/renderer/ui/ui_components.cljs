(ns meins.electron.renderer.ui.ui-components
  (:require [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [taoensso.timbre :refer [debug error info]]))


(defn select [{:keys [options entry path on-change sorted-by] :as m}]
  (let [options   (if (map? options)
                    options
                    (zipmap options options))
        sorted-by (if sorted-by sorted-by first)]
    [:select {:value     (get-in entry path "")
              :on-change (on-change m)}
     [:option ""]
     (for [[v t] (sort-by sorted-by options)]
       ^{:key v}
       [:option {:value v} t])]))

(defn select2 [{:keys [options entry path on-change] :as m}]
  [:select {:value     (get-in entry path "")
            :on-change (on-change m)}
   (for [[v t] options]
     ^{:key v}
     [:option {:value v} t])])

(defn select-update [{:keys [entry path xf]}]
  (let [xf (or xf identity)]
    (fn [ev]
      (let [tv      (h/target-val ev)
            sel     (if (empty? tv) tv (xf tv))
            updated (assoc-in entry path sel)]
        (emit [:entry/update-local updated])))))

(defn switch [{:keys [path entry msg-type on-click]}]
  (let [msg-type (or msg-type :entry/update-local)
        toggle   (or on-click
                     #(emit [msg-type (update-in entry path not)]))
        v        (get-in entry path)]
    [:div.on-off {:on-click toggle}
     [:div {:class (when-not v "inactive")} "no"]
     [:div {:class (when v "active")} "yes"]]))

(defn switch2 [{:keys [v]}]
  [:div.on-off2
   [:div {:class (when-not v "inactive")} "no"]
   [:div {:class (when v "active")} "yes"]])
