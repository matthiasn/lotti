(ns meins.custom-charts-test
  "Test that chart configuration map is proper created from the chart vector
   in the custom chart configuration."
  (:require [clojure.pprint :as pp]
            [clojure.test :refer [deftest is testing]]
            [meins.electron.renderer.charts.custom-fields-cfg :as cf]))

(def chart-def
  [{:label          "#pull-ups"
    :path           ["#pull-ups" :cnt]
    :type           :barchart
    :chart-h        35
    :threshold      4
    :threshold-type :above}
   {:label          "#squats"
    :path           ["#squats" :cnt]
    :type           :barchart
    :chart-h        35
    :threshold      20
    :threshold-type :above}
   {:label          "#lunges"
    :path           ["#lunges" :cnt]
    :type           :barchart
    :chart-h        35
    :threshold      20
    :threshold-type :above}
   {:label          "#push-ups"
    :path           ["#push-ups" :cnt]
    :type           :barchart
    :chart-h        35
    :threshold      20
    :threshold-type :above}
   {:label          "#sit-ups"
    :path           ["#sit-ups" :cnt]
    :type           :barchart
    :chart-h        35
    :threshold      25
    :threshold-type :above}
   {:label          "#plank"
    :path           ["#plank" :cnt]
    :type           :barchart
    :chart-h        35
    :threshold      25
    :threshold-type :above
    :space-after    10}
   {:label          "#running"
    :path           ["#running" :duration]
    :type           :barchart
    :chart-h        35
    :threshold      10
    :threshold-type :above}
   {:label          "#cycling"
    :path           ["#cycling" :duration]
    :type           :barchart
    :chart-h        35
    :threshold      10
    :threshold-type :above}
   {:label          "#stairsteps"
    :path           ["#stairsteps" :cnt]
    :type           :barchart
    :chart-h        35
    :threshold      10
    :threshold-type :above}
   {:label          "#crosstrainer"
    :path           ["#crosstrainer" :duration]
    :type           :barchart
    :chart-h        35
    :threshold      10
    :threshold-type :above
    :space-after    10}
   {:label          "#coffee"
    :path           ["#coffee" :cnt]
    :type           :barchart
    :chart-h        35
    :threshold      600
    :threshold-type :below}
   {:label          "#water"
    :path           ["#water" :vol]
    :type           :barchart
    :chart-h        35
    :threshold      2
    :threshold-type :above
    :space-after    10}
   {:label   "#girth abd"
    :path    ["#girth" :abdominal]
    :type    :linechart
    :cls     "line"
    :chart-h 20}
   {:label   "#girth chest"
    :path    ["#girth" :chest]
    :type    :linechart
    :cls     "line"
    :chart-h 20}])

(def expected-chart-map
  {:charts-h 595
   :charts   [{:label          "#pull-ups"
               :path           ["#pull-ups" :cnt]
               :type           :barchart
               :chart-h        35
               :threshold      4
               :threshold-type :above
               :y-start        50}
              {:label          "#squats"
               :path           ["#squats" :cnt]
               :type           :barchart
               :chart-h        35
               :threshold      20
               :threshold-type :above
               :y-start        90}
              {:label          "#lunges"
               :path           ["#lunges" :cnt]
               :type           :barchart
               :chart-h        35
               :threshold      20
               :threshold-type :above
               :y-start        130}
              {:label          "#push-ups"
               :path           ["#push-ups" :cnt]
               :type           :barchart
               :chart-h        35
               :threshold      20
               :threshold-type :above
               :y-start        170}
              {:label          "#sit-ups"
               :path           ["#sit-ups" :cnt]
               :type           :barchart
               :chart-h        35
               :threshold      25
               :threshold-type :above
               :y-start        210}
              {:label          "#plank"
               :path           ["#plank" :cnt]
               :type           :barchart
               :chart-h        35
               :threshold      25
               :threshold-type :above
               :space-after    10
               :y-start        250}
              {:label          "#running"
               :path           ["#running" :duration]
               :type           :barchart
               :chart-h        35
               :threshold      10
               :threshold-type :above
               :y-start        295}
              {:label          "#cycling"
               :path           ["#cycling" :duration]
               :type           :barchart
               :chart-h        35
               :threshold      10
               :threshold-type :above
               :y-start        335}
              {:label          "#stairsteps"
               :path           ["#stairsteps" :cnt]
               :type           :barchart
               :chart-h        35
               :threshold      10
               :threshold-type :above
               :y-start        375}
              {:label          "#crosstrainer"
               :path           ["#crosstrainer" :duration]
               :type           :barchart
               :chart-h        35
               :threshold      10
               :threshold-type :above
               :space-after    10
               :y-start        415}
              {:label          "#coffee"
               :path           ["#coffee" :cnt]
               :type           :barchart
               :chart-h        35
               :threshold      600
               :threshold-type :below
               :y-start        460}
              {:label          "#water"
               :path           ["#water" :vol]
               :type           :barchart
               :chart-h        35
               :threshold      2
               :threshold-type :above
               :space-after    10
               :y-start        500}
              {:label   "#girth abd"
               :path    ["#girth" :abdominal]
               :type    :linechart
               :cls     "line"
               :chart-h 20
               :y-start 545}
              {:label   "#girth chest"
               :path    ["#girth" :chest]
               :type    :linechart
               :cls     "line"
               :chart-h 20
               :y-start 570}]})

(deftest chart-map
  (testing "chart config map built correctly"
    (let [chart-map (cf/build-chart-map chart-def 50)]
      (testing
        "correct height"
        (is (= (:charts-h chart-map) 595)))
      (testing
        "correct chart map"
        (is (= chart-map expected-chart-map))))))
