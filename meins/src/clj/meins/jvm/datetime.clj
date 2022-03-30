(ns meins.jvm.datetime
  (:require [clj-time.coerce :as ctc]
            [clj-time.core :as ct]
            [clj-time.format :as ctf]))

(def dtz (ct/default-time-zone))

(def dt-local-fmt
  (ctf/formatter "yyyy-MM-dd'T'HH:mm" dtz))

(def dt-completion-fmt
  (ctf/formatter "yyyy-MM-dd'T'HH:mm:ssZ" dtz))

(defn fmt-from-long
  [ts]
  (ctf/unparse dt-local-fmt (ctc/from-long ts)))

(def ymd-fmt (ctf/formatter "yyyy-MM-dd" dtz))
(defn ymd [ts] (when (number? ts) (ctf/unparse ymd-fmt (ctc/from-long ts))))
(defn ymd-to-ts [s] (ctc/to-long (ctf/parse ymd-fmt s)))

(defn days-before [day n]
  (let [ts (ymd-to-ts day)]
    (ymd (- ts (* n 24 60 60 1000)))))

(defn ts-to-ymd-tz [ts tz]
  (let [tz (if (string? tz)
             (ct/time-zone-for-id tz)
             dtz)]
    (ctf/unparse (ctf/formatter "yyyy-MM-dd" tz)
                 (ctc/from-long ts))))

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
