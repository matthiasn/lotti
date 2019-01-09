(ns meins.electron.renderer.charts.custom-fields-cfg)

(defn build-chart-map
  "Build custom chart map for the given vector of individual chart configs,
   with the given start height."
  [chart-def first-y]
  (let [h-reducer (fn [acc chart-cfg]
                    (let [{:keys [chart-h space-after]} chart-cfg
                          {:keys [charts-h charts]} acc
                          chart-cfg (assoc-in chart-cfg [:y-start] charts-h)]
                      {:charts-h (+ charts-h chart-h (or space-after 5))
                       :charts  (vec (conj charts chart-cfg))}))
        initial {:charts-h first-y :charts []}
        chart-map (reduce h-reducer initial chart-def)]
    chart-map))