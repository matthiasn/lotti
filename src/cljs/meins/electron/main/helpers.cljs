(ns meins.electron.main.helpers
  (:require ["moment" :as moment]))

(defn format-time [m] (.format (moment m) "YYYY-MM-DD HH:mm"))

(def health-date-format "YYYY-MM-DD HH:mm:ss")
(defn health-date-to-ts [s] (.valueOf (moment s health-date-format)))
