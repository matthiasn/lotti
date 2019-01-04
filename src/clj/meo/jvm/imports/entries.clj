(ns meo.jvm.imports.entries
  (:require [meo.jvm.migrations :as m]
            [cheshire.core :as cc]
            [camel-snake-kebab.core :refer :all]
            [taoensso.timbre :refer [info error warn]]
            [clojure.string :as s]
            [meo.common.utils.misc :as u]
            [clj-time.format :as f]
            [clj-time.core :as t]
            [clj-time.coerce :as c]))

(defn update-audio-tag [entry]
  (if (:audio_file entry)
    (assoc-in entry [:perm_tags] #{"#audio"})
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
                       (update-audio-tag)
                       (m/add-tags-mentions)
                       (update-in [:timestamp] u/double-ts-to-long)
                       (update-in [:linked_timestamp] u/double-ts-to-long))
                   entry (if (:linked_timestamp entry)
                           (set-linked entry)
                           (update-in entry [:tags] conj "#import"))]
               (put-fn (with-meta [:entry/import entry] msg-meta))))))
       (catch Exception ex (error (str "Error while importing " filename) ex))))
