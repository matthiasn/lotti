(ns meins.electron.renderer.ui.preferences.metrics
  (:require [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [taoensso.timbre :refer [error info]]))

(defn metrics []
  (let [metrics (subscribe [:metrics])
        td-fmt (fn [v] [:td.data (.toFixed v 2)])
        get-metrics #(emit [:metrics/get])
        sort-fn #(let [data (second %)] (* (:mean data) (:n data)))]
    (get-metrics)
    (fn []
      [:div.metrics.col
       [:h2 "Backend Metrics"]
       [:span.btn {:on-click #(emit [:metrics/get])} "update"]
       (when (seq @metrics)
         (let [metrics (reverse (sort-by sort-fn @metrics))]
           [:table
            [:thead
             [:tr
              [:th "metric"]
              [:th "n"]
              [:th "total time"]
              [:th "mean"]
              [:th "std-dev"]
              [:th "smallest"]
              [:th "p75"]
              [:th "p95"]
              [:th "p99"]
              [:th "p99.9"]
              [:th "largest"]]]
            [:tbody
             (for [[metric data] metrics]
               [:tr {:key metric}
                [:td.label metric]
                [:td.data (:n data)]
                [td-fmt (* (:mean data) (:n data))]
                [td-fmt (:mean data)]
                [td-fmt (:std-dev data)]
                [td-fmt (:smallest data)]
                [td-fmt (get-in data [:percentiles 0.75])]
                [td-fmt (get-in data [:percentiles 0.95])]
                [td-fmt (get-in data [:percentiles 0.99])]
                [td-fmt (get-in data [:percentiles 0.999])]
                [td-fmt (:largest data)]])]]))])))
