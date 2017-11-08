(ns meo.jvm.imports.entries
  (:require [clojure.pprint :as pp]
            [meo.jvm.files :as f]
            [meo.jvm.migrations :as m]
            [meo.jvm.imports.screenshot :as is]
            [meo.jvm.imports.spotify :as iss]
            [meo.common.specs :as specs]
            [meo.jvm.imports.flight :as fl]
            [meo.jvm.imports.media :as im]
            [clj-time.coerce :as c]
            [clj-time.core :as t]
            [cheshire.core :as cc]
            [camel-snake-kebab.core :refer :all]
            [clj-time.coerce :as c]
            [me.raynes.fs :as fs]
            [clj-http.client :as hc]
            [clj-time.format :as tf]
            [clojure.tools.logging :as log]
            [clojure.java.io :as io]
            [clojure.string :as s]
            [meo.common.utils.misc :as u]
            [meo.jvm.file-utils :as fu]
            [clj-time.format :as ctf]))

(defn import-visits-fn
  [rdr put-fn msg-meta filename]
  (try
    (let [lines (line-seq rdr)]
      (doseq [line lines]
        (let [raw-visit (cc/parse-string line #(keyword (s/replace % "_" "-")))
              {:keys [arrival-ts departure-ts]} (u/visit-timestamps raw-visit)
              dur (when departure-ts
                    (-> (- departure-ts arrival-ts)
                        (/ 6000)
                        (Math/floor)
                        (/ 10)))
              visit (merge raw-visit
                           {:timestamp arrival-ts
                            :md        (if dur
                                         (str "Duration: " dur "m #visit")
                                         "No departure recorded #visit")
                            :tags      #{"#visit" "#import"}})]
          (if-not (neg? (:timestamp visit))
            (put-fn (with-meta [:entry/import visit] msg-meta))
            (log/warn "negative timestamp?" visit)))))
    (catch Exception ex (log/error "Error while importing " filename ex))))

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
                     (assoc-in entry [:linked-entries]
                               (when-let [linked (:linked-timestamp entry)]
                                 #{linked})))
                   entry
                   (-> (cc/parse-string line #(keyword (s/replace % "_" "-")))
                       (m/add-tags-mentions)
                       (update-audio-tag)
                       (update-in [:timestamp] u/double-ts-to-long)
                       (update-in [:linked-timestamp] u/double-ts-to-long))
                   entry (if (:linked-timestamp entry)
                           (set-linked entry)
                           (update-in entry [:tags] conj "#import"))]
               (put-fn (with-meta [:entry/import entry] msg-meta))))))
       (catch Exception ex (log/error (str "Error while importing "
                                           filename) ex))))
