(ns meo.jvm.datetime
  (:require [clj-time.core :as ct]
            [clj-time.coerce :as c]
            [clj-time.format :as ctf]))

(def dt-local-fmt
  (ctf/formatter "yyyy-MM-dd'T'HH:mm" (ct/default-time-zone)))

(def dt-completion-fmt
  (ctf/formatter "yyyy-MM-dd'T'HH:mm:ssZ" (ct/default-time-zone)))

(defn fmt-from-long
  [ts]
  (ctf/unparse dt-local-fmt (c/from-long ts)))

(def ymd-fmt (ctf/formatter "yyyy-MM-dd" (ct/default-time-zone)))
(defn ts-to-ymd [ts] (ctf/unparse ymd-fmt (c/from-long ts)))
