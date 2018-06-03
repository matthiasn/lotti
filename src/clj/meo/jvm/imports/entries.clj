(ns meo.jvm.imports.entries
  (:require [meo.jvm.migrations :as m]
            [cheshire.core :as cc]
            [camel-snake-kebab.core :refer :all]
            [taoensso.timbre :refer [info error warn]]
            [clojure.string :as s]
            [meo.common.utils.misc :as u]))

(defn import-visits-fn
  [rdr put-fn msg-meta filename]
  (try
    (let [lines (line-seq rdr)]
      (doseq [line lines]
        (let [raw-visit (cc/parse-string line keyword)
              {:keys [arrival_ts departure_ts]} (u/visit-timestamps raw-visit)
              dur (when departure_ts
                    (-> (- departure_ts arrival_ts)
                        (/ 6000)
                        (Math/floor)
                        (/ 10)))
              visit (merge raw-visit
                           {:timestamp arrival_ts
                            :md        (if dur
                                         (str "Duration: " dur "m #visit")
                                         "No departure recorded #visit")
                            :tags      #{"#visit" "#import"}})]
          (if-not (neg? (:timestamp visit))
            (put-fn (with-meta [:entry/import visit] msg-meta))
            (warn "negative timestamp?" visit)))))
    (catch Exception ex (error "Error while importing " filename ex))))

(defn update-audio-tag
  [entry]
  (if (:audio-file entry)
    (-> entry
        (update-in [:tags] conj "#audio")
        (update-in [:md] str " #audio"))
    entry))

(defn import-text-entries-fn
  [rdr put-fn msg-meta filename]
  (try (let [lines (line-seq rdr)]
         (doseq [line lines]
           (when (seq line)
             (let [set-linked
                   (fn [entry]
                     (assoc-in entry [:linked_entries]
                               (when-let [linked (:linked_timestamp entry)]
                                 #{linked})))
                   entry
                   (-> (cc/parse-string line keyword)
                       (m/add-tags-mentions)
                       (update-audio-tag)
                       (update-in [:timestamp] u/double-ts-to-long)
                       (update-in [:linked_timestamp] u/double-ts-to-long))
                   entry (if (:linked_timestamp entry)
                           (set-linked entry)
                           (update-in entry [:tags] conj "#import"))]
               (put-fn (with-meta [:entry/import entry] msg-meta))))))
       (catch Exception ex (error (str "Error while importing " filename) ex))))
