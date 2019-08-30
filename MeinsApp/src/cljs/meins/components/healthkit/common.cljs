(ns meins.components.healthkit.common
  (:require [matthiasn.systems-toolbox.component :as st]))

(defn date-from-ts [ts]
  (let [date (js/Date. ts)]
    (.toISOString date)))

(defn days-ago [n]
  (let [offset (* n 24 60 60 1000)]
    (date-from-ts (- (st/now) offset))))

(def hk-opts
  (clj->js
    {:permissions
     {:read ["Height" "Weight" "StepCount" "BodyMassIndex" "FlightsClimbed"
             "BloodPressureDiastolic" "BloodPressureSystolic" "HeartRate"
             "DistanceWalkingRunning" "SleepAnalysis" "RespiratoryRate"
             "DistanceCycling" "MindfulSession" "ActiveEnergyBurned"
             "WalkingHeartRateAverage" "RestingHeartRate"
             "BodyFatPercentage" "HeartRateVariability"
             "ActiveEnergyBurned" "BasalEnergyBurned"
             "AppleExerciseTime"]}}))
