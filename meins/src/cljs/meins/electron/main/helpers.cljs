(ns meins.electron.main.helpers
  (:require ["moment" :as moment]
            ["fs" :refer [readFileSync]]
            [cljs.tools.reader.edn :as edn]))

(defn format-time [m] (.format (moment m) "YYYY-MM-DD HH:mm"))

(def health-date-format "YYYY-MM-DD HH:mm:ss")
(defn health-date-to-ts [s] (.valueOf (moment s health-date-format)))

(def health-date-format2 "YYYY-MM-DDTHH:mm:ss:SSS")
(defn health-date-to-ts2 [s] (.valueOf (moment s health-date-format2)))

(defn parse-json [file]
  (let [json (.parse js/JSON (readFileSync file))
        data (js->clj json)]
    data))

(defn parse-edn [file]
  (edn/read-string (readFileSync file "utf-8")))
