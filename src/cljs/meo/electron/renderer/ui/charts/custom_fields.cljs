(ns meo.electron.renderer.ui.charts.custom-fields
  (:require [reagent.core :as rc]
            [meo.electron.renderer.ui.charts.common :as cc]
            [meo.electron.renderer.helpers :as h]
            [meo.electron.renderer.charts.custom-fields-cfg :as cf]
            [re-frame.core :refer [subscribe]]
            [goog.string :as gstring]
            [goog.string.format]
            [clojure.pprint :as pp]
            [reagent.core :as r]))

(defn mouse-leave-fn
  "Creates event handler that removes the keys required for the info div
   when leaving an element, such as a bar or circle in an SVG chart."
  [local v]
  (fn [_ev]
    (when (= v (:mouse-over @local))
      (swap! local (fn [state] (-> state
                                   (dissoc :mouse-over)
                                   (dissoc :mouse-over-path)
                                   (dissoc :mouse-over-label)
                                   (dissoc :mouse-pos)))))))

(defn mouse-enter-fn
  "Creates event handler for mouse-enter events on elements in a chart.
   Takes a local atom and the value associated with the chart element.
   Returns function which detects the mouse position from the event and
   replaces :mouse-over key in local atom with v and :mouse-pos with the
   mouse position in the event. Also sets path that specifies where to find
   the data of the moused over element."
  [local day-stats path k]
  (fn [ev]
    (let [mouse-pos {:x (.-pageX ev) :y (.-pageY ev)}
          update-fn (fn [state day-stats]
                      (-> state
                          (assoc-in [:mouse-over] day-stats)
                          (assoc-in [:mouse-over-path] path)
                          (assoc-in [:mouse-over-label] k)
                          (assoc-in [:mouse-pos] mouse-pos)))]
      (swap! local update-fn day-stats)
      (.setTimeout js/window (mouse-leave-fn local day-stats) 7500))))

(defn linechart-row
  "Draws line chart."
  [indexed local  cfg k]
  (let [{:keys [path chart-h y-start cls]} cfg
        vals (filter second (map (fn [[k v]] [k (get-in v path)]) indexed))
        max-val (or (apply max (map second vals)) 10)
        min-val (or (apply min (map second vals)) 1)
        y-scale (/ chart-h (- max-val min-val))
        mapper (fn [[idx v]]
                 (let [x (+ 5 (* 10 idx))
                       y (- (+ chart-h y-start) (* y-scale (- v min-val)))]
                   (str x "," y)))
        points (cc/line-points vals mapper)
        color (cc/item-color path)]
    [:g {:class cls}
     [:g
      [:polyline {:points points
                  :style  {:stroke color}}]
      (for [[idx day] (filter #(get-in (second %) path) indexed)]
        (let [w (get-in day path)
              mouse-enter-fn (mouse-enter-fn local day path k)
              mouse-leave-fn (mouse-leave-fn local day)
              cy (- (+ chart-h y-start) (* y-scale (- w min-val)))]
          ^{:key (str path idx)}
          [:circle {:cx             (+ (* 10 idx) 5)
                    :cy             cy
                    :r              4
                    :style          {:stroke color}
                    :on-mouse-enter mouse-enter-fn
                    :on-mouse-leave mouse-leave-fn}]))]]))

(defn barchart-row
  "Renders bars."
  [indexed local put-fn cfg k]
  (let [{:keys [path chart-h y-start threshold threshold-type]} cfg
        max-val (or (:max cfg)
                    (apply max (map (fn [[_idx v]] (get-in v path)) indexed)))]
    [:g
     (for [[idx day] indexed]
       (let [y-end (+ chart-h y-start)
             y-scale (/ chart-h (or max-val 1))
             v (get-in day path)
             h (if (pos? v) (* y-scale v) 5)
             mouse-enter-fn (mouse-enter-fn local day path k)
             mouse-leave-fn (mouse-leave-fn local day)
             threshold-fn (if (= threshold-type :below) < >=)
             threshold-reached? (threshold-fn v threshold)]
         (when (pos? max-val)
           ^{:key (str path idx)}
           [:rect {:x              (* 10 idx)
                   :on-click       (cc/open-day-fn day put-fn)
                   :y              (- y-end h)
                   :width          9
                   :height         h
                   :class          (if threshold-reached?
                                     (cc/weekend-class "done" day)
                                     (cc/weekend-class "failed" day))
                   :on-mouse-enter mouse-enter-fn
                   :on-mouse-leave mouse-leave-fn}])))]))

(defn custom-fields-chart
  "Draws custom fields chart, with a row for each configured chart. The
   position of each chart is calculated in the cf namespace."
  [put-fn]
  (let [local (rc/atom {})
        stats (subscribe [:custom-field-stats])
        options (subscribe [:options])
        last-update (subscribe [:last-update])]
    (fn custom-fields-chart-render [put-fn]
      (let [charts-vec (:custom-field-charts @options)
            chart-map (cf/build-chart-map charts-vec 55)
            charts-h (:charts-h chart-map)
            dom-node (rc/dom-node (rc/current-component))
            w (if dom-node (.-offsetWidth dom-node) 300)
            n (.floor js/Math (/ w 5))
            n 120
            indexed (map-indexed (fn [idx [k v]] [idx v]) (take-last n @stats))]
        [:div.stats.custom
         [:svg {:viewBox (str "0 0 " (* 2 w) " " charts-h)}
          [cc/chart-title "custom fields" w]
          [cc/bg-bars indexed local charts-h :custom]
          (for [row-cfg (:charts chart-map)]
            (let [k (:label row-cfg)]
              (if (= :barchart (:type row-cfg))
                ^{:key (str :custom-fields-barchart (:path row-cfg))}
                [barchart-row indexed local put-fn row-cfg k]
                ^{:key (str :custom-fields-linechart (:path row-cfg))}
                [linechart-row indexed local row-cfg k])))]
         (when-let [mouse-over (:mouse-over @local)]
           (let [path (:mouse-over-path @local)
                 v (get-in mouse-over path)
                 fmt (when v (gstring/format "%.1f" v))]
             [:div.mouse-over-info (cc/info-div-pos @local)
              [:div (:date_string mouse-over)]
              (when path
                [:div [:strong (:mouse-over-label @local)] ": " fmt])]))]))))
