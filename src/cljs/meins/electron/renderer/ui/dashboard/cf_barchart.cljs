(ns meins.electron.renderer.ui.dashboard.cf_barchart
  (:require ["moment" :as moment]
            [clojure.string :as s]
            [meins.common.utils.parse :as up]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.dashboard.common :as dc]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug info]]))

(def ymd "YYYY-MM-DD")
(defn df [ts format] (.format (moment ts) format))

(defn rect
  [{:keys [v x w y h tag ymd color label local]}]
  (let [display-text [:span ymd ": " [:strong v] " " label]
        enter #(swap! local assoc :display-text display-text)
        leave #(swap! local assoc :display-text "")
        click #(let [q (merge (up/parse-search tag)
                              {:from ymd
                               :to   ymd})]
                 (emit [:search/add {:tab-group :right
                                     :query     q}]))]
    [:g
     [:rect {:on-mouse-enter enter
             :on-mouse-leave leave
             :on-click       click
             :x              x
             :y              (- y h)
             :width          w
             :height         h
             :fill           color}]]))

(defn indexed-days [stats tag k start days]
  (let [d (* 24 60 60 1000)
        rng (range (inc days))
        indexed (map-indexed (fn [n _v]
                               (let [offset (* n d)
                                     ts (+ start offset)
                                     ymd (df ts ymd)
                                     v (get-in stats [ymd tag k] 0)]
                                 [n {:ymd ymd
                                     :v   v}]))
                             rng)]
    indexed))

(defn barchart-row [_]
  (let [dashboard-data (subscribe [:dashboard-data])
        backend-cfg (subscribe [:backend-cfg])
        pvt (subscribe [:show-pvt])
        custom-fields (reaction (:custom-fields @backend-cfg))]
    (fn barchart-row [{:keys [days span mx tag h y field color local
                              cls threshold success-cls start end]}]
      (when (and tag field (seq tag))
        (let [btm-y (+ y h)
              qid (keyword (s/replace (subs (str tag) 1) "-" "_"))
              start-ymd (h/ymd start)
              end-ymd (h/ymd end)
              data (->> @dashboard-data
                        (filter #(<= start-ymd (first %)))
                        (filter #(> end-ymd (first %)))
                        (map second)
                        (map #(get-in % [:custom-fields tag])))
              indexed (map-indexed (fn [i x]
                                     [i (merge x {:day-ts (h/ymd-to-ts (:date_string x))})])
                                   data)
              label (get-in @custom-fields [tag :fields (keyword field) :label])
              field-type (get-in @custom-fields [tag :fields (keyword field) :cfg :type])
              mx (or mx
                     (apply max 1 (map
                                    (fn [x]
                                      (:value
                                        (first (filter #(= (name field) (:field %))
                                                       (:fields x)))
                                        0))
                                    data)))
              scale (if (pos? mx) (/ (- h 3) mx) 1)
              line-inc (cond
                         (> mx 12000) 10000
                         (> mx 8000) 5000
                         (> mx 4000) 2500
                         (> mx 2000) 1000
                         (> mx 1500) 1000
                         (> mx 800) 500
                         (> mx 400) 250
                         (> mx 100) 50
                         (> mx 40) 25
                         :else 10)
              lines (filter #(zero? (mod % line-inc)) (range 1 mx))]
          [:g
           [dc/row-label (or label tag) y h]
           (for [n lines]
             ^{:key (str qid n)}
             [dc/line (- btm-y (* n scale)) "#888" 1])
           (when @pvt
             (for [n lines]
               ^{:key (str qid n)}
               [:text {:x           624
                       :y           (- (+ btm-y 5) (* n scale))
                       :font-size   11
                       :fill        "black"
                       :text-anchor "start"}
                (+ n)]))
           (for [[n {:keys [date_string day-ts fields]}] indexed]
             (let [field (first (filter #(= (name field) (:field %)) fields))
                   v (:value field 0)
                   offset (- day-ts start)
                   span (if (zero? span) 1 span)
                   scaled (* days 20 (/ offset span))
                   x (+ 201 scaled)
                   v (min mx v)
                   h (* v scale)
                   cls (if (and threshold (> v threshold))
                         success-cls
                         cls)
                   display-v (if (= :time field-type)
                               (h/m-to-hh-mm v)
                               v)]
               (when-not (js/isNaN x)
                 ^{:key (str tag field n)}
                 [rect {:v     display-v
                        :x     x
                        :w     16
                        :ymd   date_string
                        :y     btm-y
                        :h     h
                        :label label
                        :local local
                        :tag   tag
                        :cls   cls
                        :color color
                        :n     n}])))
           [dc/line (+ y h) "#000" 2]])))))
