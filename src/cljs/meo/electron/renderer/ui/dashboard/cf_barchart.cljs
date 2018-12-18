(ns meo.electron.renderer.ui.dashboard.cf_barchart
  (:require [moment]
            [re-frame.core :refer [subscribe]]
            [meo.electron.renderer.helpers :as h]
            [reagent.ratom :refer-macros [reaction]]
            [reagent.core :as r]
            [taoensso.timbre :refer-macros [info debug]]
            [clojure.string :as s]
            [meo.electron.renderer.ui.charts.common :as cc]
            [meo.electron.renderer.ui.dashboard.common :as dc]))

(def ymd "YYYY-MM-DD")
(defn df [ts format] (.format (moment ts) format))

(defn rect [{:keys []}]
  (let []
    (fn [{:keys [v x w y h cls ymd color label local]}]
      (let [display-text [:span ymd ": " [:strong v] " " label]
            enter #(swap! local assoc :display-text display-text)
            leave #(swap! local assoc :display-text "")]
        [:g
         [:rect {:on-mouse-enter enter
                 :on-mouse-leave leave
                 :x              x
                 :y              (- y h)
                 :width          w
                 :height         h
                 :fill           color}]
         (when (:show-label @local)
           [:text {:x           (+ x 11)
                   :y           (- y 5)
                   :font-size   8
                   :fill        "#777"
                   :text-anchor "middle"}
            v])]))))

(defn indexed-days [stats tag k start days]
  (let [d (* 24 60 60 1000)
        rng (range (inc days))
        indexed (map-indexed (fn [n v]
                               (let [offset (* n d)
                                     ts (+ start offset)
                                     ymd (df ts ymd)
                                     v (get-in stats [ymd tag k] 0)]
                                 [n {:ymd ymd
                                     :v   v}]))
                             rng)]
    indexed))

(defn barchart-row [_ _]
  (let [gql-res (subscribe [:gql-res])
        backend-cfg (subscribe [:backend-cfg])
        custom-fields (reaction (:custom-fields @backend-cfg))]
    (fn barchart-row [{:keys [days span mx tag h y field color local
                              cls threshold success-cls] :as m} put-fn]
      (when (and tag field (seq tag))
        (let [btm-y (+ y h)
              qid (keyword (s/replace (subs (str tag) 1) "-" "_"))
              data (get-in @gql-res [:dashboard :data qid])
              indexed (map-indexed (fn [i x] [i x]) data)
              label (get-in @custom-fields [tag :fields (keyword field) :label])
              field-type (get-in @custom-fields [tag :fields (keyword field) :cfg :type])
              mx (or mx
                     (apply max (map
                                  (fn [x]
                                    (:value
                                      (first (filter #(= (name field) (:field %))
                                                     (:fields x)))
                                      0))
                                  data)))
              scale (if (pos? mx) (/ (- h 3) mx) 1)]
          [:g
           [dc/row-label (or label tag) y h]
           (for [[n {:keys [date_string fields]}] indexed]
             (let [field (first (filter #(= (name field) (:field %)) fields))
                   v (:value field 0)
                   d (* 24 60 60 1000)
                   offset (* n d)
                   span (if (zero? span) 1 span)
                   scaled (* 1800 (/ offset span))
                   x (+ 201 scaled)
                   v (min mx v)
                   h (* v scale)
                   cls (if (and threshold (> v threshold))
                         success-cls
                         cls)
                   display-v (if (= :time field-type)
                               (h/m-to-hh-mm v)
                               v)]
               ^{:key (str tag field n)}
               [rect {:v     display-v
                      :x     x
                      :w     (/ 1500 days)
                      :ymd   date_string
                      :y     btm-y
                      :h     h
                      :label label
                      :local local
                      :tag   tag
                      :cls   cls
                      :color color
                      :n     n}]))
           [dc/line (+ y h) "#000" 2]])))))
