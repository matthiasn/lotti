(ns meo.jvm.datetime
  (:require [clj-time.core :as ct]
            [clj-time.coerce :as c]
            [clj-time.format :as ctf]
            [clj-time.coerce :as ctc]))

(def dtz (ct/default-time-zone))

(def dt-local-fmt
  (ctf/formatter "yyyy-MM-dd'T'HH:mm" dtz))

(def dt-completion-fmt
  (ctf/formatter "yyyy-MM-dd'T'HH:mm:ssZ" dtz))

(defn fmt-from-long
  [ts]
  (ctf/unparse dt-local-fmt (c/from-long ts)))

(def ymd-fmt (ctf/formatter "yyyy-MM-dd" dtz))
(defn ts-to-ymd [ts] (ctf/unparse ymd-fmt (c/from-long ts)))
(defn ymd-to-ts [s] (c/to-long (ctf/parse ymd-fmt s)))

(defn ts-to-ymd-tz [ts tz]
  (let [tz (if (string? tz)
             (ct/time-zone-for-id tz)
             dtz)]
    (ctf/unparse (ctf/formatter "yyyy-MM-dd" tz)
                 (c/from-long ts))))

(defn local-dt [ts]
  (-> ts
      (ctc/from-long)
      (ct/to-time-zone (ct/default-time-zone))))

(defn dt-tz [ts tz]
  (let [tz (if (string? tz)
             (ct/time-zone-for-id tz)
             dtz)]
    (-> ts
        (ctc/from-long)
        (ct/to-time-zone tz))))
