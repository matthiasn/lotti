(ns meins.jvm.migrations
  "This namespace is used for migrating entries to new versions."
  (:require [camel-snake-kebab.core :refer :all]
            [camel-snake-kebab.extras :refer [transform-keys]]
            [cheshire.core :as cc]
            [clj-http.client :as hc]
            [clj-time.coerce :as c]
            [clj-time.core :as ct]
            [clj-time.format :as ctf]
            [clj-uuid :as uuid]
            [clojure.data.json :as json]
            [clojure.pprint :as pp]
            [geo [geohash :as geohash] [spatial :as spatial]]
            [me.raynes.fs :as fs]
            [meins.jvm.datetime :as dt]
            [meins.jvm.files :as f]
            [taoensso.timbre :refer [error info]])
  #_(:import (io.dgraph DgraphClient DgraphGrpc DgraphProto$Mutation)
      (io.grpc ManagedChannelBuilder)
      (com.google.protobuf ByteString)))

(defn to-snake [k]
  (cond
    (number? k) k
    :else (->snake_case k)))

(defn snake-xf [xs] (transform-keys to-snake xs))


(defn add-tags-mentions
  "Parses entry for hashtags and mentions."
  [entry]
  (when-let [text (:md entry)]
    (let [tags (set (re-seq #"(?m)(?!^)#[\w-]+" text))
          mentions (set (re-seq #"@\w+" text))]
      (merge entry
             {:tags     tags
              :mentions mentions}))))

(defn migrate-entries
  "Initial state function, creates state atom and then parses all files in
  data directory into the component state."
  [conversion-fn]
  (let [files (file-seq (clojure.java.io/file "./data"))]
    (doseq [f (f/filter-by-name files #"\d{13}.edn")]
      (let [parsed (clojure.edn/read-string (slurp f))
            converted (conversion-fn parsed)
            filename (str "./data/" (:timestamp converted) ".edn")]
        (when converted
          (spit filename (with-out-str (pp/pprint converted))))))))

(defn migrate-to-uuids
  ; (migrate-to-uuids "./data/migration/daily-logs" "./data/daily-logs/2017-03-19.jrn")
  [path out-file]
  (let [files (file-seq (clojure.java.io/file path))
        ts-uuid (atom {})]
    (doseq [f (f/filter-by-name files #"\d{4}-\d{2}-\d{2}a?.jrn")]
      (with-open [reader (clojure.java.io/reader f)]
        (prn f)
        (let [lines (line-seq reader)]
          (doseq [line lines]
            (try
              (let [parsed (clojure.edn/read-string line)
                    ts (:timestamp parsed)
                    id (or (:id parsed)
                           (get-in @ts-uuid [ts])
                           (uuid/v1))
                    entry (merge parsed {:id id})
                    without-raw-exif (dissoc entry :raw-exif)
                    serialized (str (pr-str without-raw-exif) "\n")]
                (swap! ts-uuid assoc-in [ts] id)
                (spit out-file serialized :append true))
              (catch Exception ex
                (error "Exception" ex "when parsing line:\n" line)))))))
    (info (count @ts-uuid) "migrated")))

(defn migrate-books-to-sagas
  ; (migrate-to-uuids "./data/migration/book-to-saga" "./data/migration/2017-03-20.jrn")
  [path out-file]
  (let [files (file-seq (clojure.java.io/file path))
        ts-uuid (atom {})]
    (doseq [f (f/filter-by-name files #"\d{4}-\d{2}-\d{2}a?.jrn")]
      (with-open [reader (clojure.java.io/reader f)]
        (prn f)
        (let [lines (line-seq reader)]
          (doseq [line lines]
            (try
              (let [parsed (clojure.edn/read-string line)
                    entry (cond
                            (= (:entry_type parsed) :book)
                            (-> parsed
                                (assoc-in [:entry_type] :saga)
                                (assoc-in [:saga-name] (:book-name parsed))
                                (dissoc :book-name))

                            (= (:entry_type parsed) :story)
                            (-> parsed
                                (dissoc :linked-book)
                                (assoc-in [:linked-saga] (:linked-book parsed)))

                            :else parsed)
                    ts (:timestamp parsed)
                    serialized (str (pr-str entry) "\n")]
                (swap! ts-uuid assoc-in [ts] entry)
                (spit out-file serialized :append true))
              (catch Exception ex
                (error "Exception" ex "when parsing line:\n" line)))))))
    (info (count @ts-uuid) "migrated")))

(defn migrate-weight
  ; (migrate-weight "./data/migration/weight" "./data/migration/2017-03-23.jrn")
  [path out-file]
  (let [files (file-seq (clojure.java.io/file path))
        ts-uuids (atom {})
        weight-entry-uuids (atom {})]
    (doseq [f (f/filter-by-name files #"\d{4}-\d{2}-\d{2}a?.jrn")]
      (with-open [reader (clojure.java.io/reader f)]
        (prn f)
        (let [lines (line-seq reader)]
          (doseq [line lines]
            (try
              (let [parsed (clojure.edn/read-string line)
                    p [:measurements :weight :value]
                    ts (:timestamp parsed)
                    entry (if-let [w (get-in parsed p)]
                            (do
                              (swap! weight-entry-uuids assoc-in [ts] parsed)
                              (assoc-in parsed [:custom-fields "#weight" :weight] w))
                            parsed)
                    serialized (str (pr-str entry) "\n")]
                (swap! ts-uuids assoc-in [ts] entry)
                (spit out-file serialized :append true))
              (catch Exception ex
                (error "Exception" ex "when parsing line:\n" line)))))))
    (info (count @weight-entry-uuids) "-" (count @ts-uuids) "migrated.")))

(defn get-geoname [entry]
  (let [lat (:latitude entry)
        lon (:longitude entry)
        parser (fn [res] (cc/parse-string (:body res) #(keyword (->kebab-case %))))]
    (when (and lat lon)
      (let [res (hc/get (str "http://localhost:3003/geocode?latitude=" lat "&longitude=" lon))
            geoname (ffirst (parser res))]
        geoname))))

(defn remove-deleted
  "Lookup geolocation for entries with lat and lon."
  ; (use 'meins.jvm.migrations)
  ; (time (m/remove-deleted "./data/migration/remove-deleted" "./data/migration/out/"))
  [path out-dir]
  (let [files (file-seq (clojure.java.io/file path))
        state (atom {:deleted #{}})
        geonames-path "./data/geonames/"
        local-fmt (ctf/with-zone (ctf/formatters :year-month-day)
                                 (ct/default-time-zone))]
    (fs/mkdirs out-dir)
    (doseq [f (f/filter-by-name files #"\d{4}-\d{2}-\d{2}a?.jrn")]
      (with-open [reader (clojure.java.io/reader f)]
        (let [lines (line-seq reader)]
          (doseq [line lines]
            (try
              (let [parsed (clojure.edn/read-string line)]
                (when (:deleted parsed)
                  (let [ts (:timestamp parsed)]
                    (swap! state update-in [:deleted] #(set (conj % ts))))))
              (catch Exception ex
                (error "Exception" ex "when parsing line:\n" line)))))))
    (doseq [f (f/filter-by-name files #"\d{4}-\d{2}-\d{2}a?.jrn")]
      (with-open [reader (clojure.java.io/reader f)]
        (let [lines (line-seq reader)
              filename (.getName f)]
          (info filename)
          (doseq [line lines]
            (try
              (let [parsed (clojure.edn/read-string line)
                    ts (:timestamp parsed)
                    serialized (str (pr-str parsed) "\n")
                    out-file (str out-dir filename)]
                (when-not (contains? (:deleted @state) ts)
                  (spit out-file serialized :append true)))
              (catch Exception ex
                (error "Exception" ex "when parsing line:\n" line)))))))
    (let [deleted (:deleted @state)]
      (info (count deleted) " deleted."))))


(defn migrate-linked-stories
  ; (m/migrate-linked-stories "./data/migration/linked" "./data/migration/linked-out")
  [path out-path]
  (let [files (file-seq (clojure.java.io/file path))
        ts-uuids (atom {})
        line-count (atom 0)]
    (doseq [f (f/filter-by-name files #"\d{4}-\d{2}-\d{2}a?.jrn")]
      (with-open [reader (clojure.java.io/reader f)]
        (let [filename (.getName f)]
          (let [lines (line-seq reader)]
            (doseq [line lines]
              (try
                (let [parsed (clojure.edn/read-string line)
                      entry (if-let [linked-story (:linked-story parsed)]
                              (-> parsed
                                  (assoc-in [:linked-stories] #{linked-story})
                                  (assoc-in [:primary-story] linked-story))
                              parsed)
                      ts (:timestamp parsed)
                      serialized (str (pr-str entry) "\n")]
                  (swap! line-count inc)
                  (swap! ts-uuids assoc-in [ts] entry)
                  (spit (str out-path "/" filename) serialized :append true))
                (catch Exception ex
                  (error "Exception" ex "when parsing line:\n" line)))))))
      (info (count @ts-uuids) "entries in" @line-count "lines migrated."))))

;(m/migrate-to-vclock "./data/migrations/vclock" "./data/migrations/vclock-out" "some-uuid")
(defn migrate-to-vclock [path out-path node-id]
  (let [files (file-seq (clojure.java.io/file path))
        ts-uuids (atom #{})
        line-count (atom 0)
        files (f/filter-by-name files #"\d{4}-\d{2}-\d{2}a?.jrn")
        sorted-files (sort-by #(.getName %) files)]
    (fs/mkdirs out-path)
    (doseq [f sorted-files]
      (with-open [reader (clojure.java.io/reader f)]
        (let [filename (.getName f)
              lines (line-seq reader)]
          (doseq [line lines]
            (try
              (swap! line-count inc)
              (let [entry (-> (clojure.edn/read-string line)
                              (assoc-in [:vclock] {node-id @line-count}))
                    id (:timestamp entry)
                    no-editor-state (dissoc entry :editor-state)
                    serialized (str (pr-str no-editor-state) "\n")]
                (swap! ts-uuids conj id)
                (spit (str out-path "/" filename) serialized :append true))
              (catch Exception ex
                (error "Exception" ex "when parsing line:\n" line))))
          (info filename "-" (count @ts-uuids) "entries," @line-count "lines"))))))

;(m/migrate-to-snake-case "./data/migrations/snake" "./data/migrations/snake-out")
(defn migrate-to-snake-case [path out-path]
  (let [files (file-seq (clojure.java.io/file path))
        ts-uuids (atom #{})
        line-count (atom 0)
        files (f/filter-by-name files #"\d{4}-\d{2}-\d{2}a?.jrn")
        sorted-files (sort-by #(.getName %) files)]
    (fs/mkdirs out-path)
    (doseq [f sorted-files]
      (with-open [reader (clojure.java.io/reader f)]
        (let [filename (.getName f)
              lines (line-seq reader)]
          (doseq [line lines]
            (try
              (swap! line-count inc)
              (let [entry (clojure.edn/read-string line)
                    snake (snake-xf entry)
                    id (:timestamp entry)
                    serialized (str (pr-str snake) "\n")]
                (swap! ts-uuids conj id)
                (spit (str out-path "/" filename) serialized :append true))
              (catch Exception ex
                (error "Exception" ex "when parsing line:\n" line))))
          (info filename "-" (count @ts-uuids) "entries," @line-count "lines"))))))

;(m/migrate-to-adjusted-ts "./data/migrations/adjusted-ts" "./data/migrations/adjusted-ts-out")
(defn migrate-to-adjusted-ts [path out-path]
  (let [files (file-seq (clojure.java.io/file path))
        ts-uuids (atom #{})
        line-count (atom 0)
        files (f/filter-by-name files #"\d{4}-\d{2}-\d{2}a?.jrn")
        sorted-files (sort-by #(.getName %) files)]
    (fs/mkdirs out-path)
    (doseq [f sorted-files]
      (with-open [reader (clojure.java.io/reader f)]
        (let [filename (.getName f)
              lines (line-seq reader)]
          (doseq [line lines]
            (try
              (swap! line-count inc)
              (let [entry (clojure.edn/read-string line)
                    id (:timestamp entry)
                    entry (if-let [for-day (:for_day entry)]
                            (let [adjusted-ts (c/to-long (ctf/parse dt/dt-local-fmt for-day))]
                              (assoc-in entry [:adjusted_ts] adjusted-ts))
                            entry)
                    serialized (str (pr-str entry) "\n")]
                (swap! ts-uuids conj id)
                (spit (str out-path "/" filename) serialized :append true))
              (catch Exception ex
                (error "Exception" ex "when parsing line:\n" line))))
          (info filename "-" (count @ts-uuids) "entries," @line-count "lines"))))))

;(m/migrate-geohash "./data/migrations/geohash" "./data/migrations/geohash-out")
(defn migrate-geohash [path out-path]
  (let [files (file-seq (clojure.java.io/file path))
        ts-uuids (atom #{})
        line-count (atom 0)
        files (f/filter-by-name files #"\d{4}-\d{2}-\d{2}a?.jrn")
        sorted-files (sort-by #(.getName %) files)]
    (fs/mkdirs out-path)
    (doseq [f sorted-files]
      (with-open [reader (clojure.java.io/reader f)]
        (let [filename (.getName f)
              lines (line-seq reader)]
          (doseq [line lines]
            (try
              (swap! line-count inc)
              (let [entry (clojure.edn/read-string line)
                    id (:timestamp entry)
                    lat (:latitude entry)
                    lon (:longitude entry)
                    entry (if (and lat lon)
                            (let [gh (geohash/geohash lat lon 45)]
                              (assoc-in entry [:geohash] (geohash/string gh)))
                            entry)
                    serialized (str (pr-str entry) "\n")]
                (swap! ts-uuids conj id)
                (spit (str out-path "/" filename) serialized :append true))
              (catch Exception ex
                (error "Exception" ex "when parsing line:\n" line))))
          (info filename "-" (count @ts-uuids) "entries," @line-count "lines"))))))

;(m/migrate-to-versioned-habits "./data/migrations/versioned-habits" "./data/migrations/versioned-habits-out")
(defn migrate-to-versioned-habits [path out-path]
  (let [files (file-seq (clojure.java.io/file path))
        ts-uuids (atom #{})
        line-count (atom 0)
        files (f/filter-by-name files #"\d{4}-\d{2}-\d{2}a?.jrn")
        sorted-files (sort-by #(.getName %) files)]
    (fs/mkdirs out-path)
    (doseq [f sorted-files]
      (with-open [reader (clojure.java.io/reader f)]
        (let [filename (.getName f)
              lines (line-seq reader)]
          (doseq [line lines]
            (try
              (swap! line-count inc)
              (let [entry (clojure.edn/read-string line)
                    id (:timestamp entry)
                    entry (if (:habit entry)
                            (let [criteria (get-in entry [:habit :criteria])]
                              (-> entry
                                  (assoc-in [:habit :versions 0 :criteria] criteria)
                                  (assoc-in [:habit :versions 0 :valid_from] "1970-01-01")))
                            entry)
                    serialized (str (pr-str entry) "\n")]
                (swap! ts-uuids conj id)
                (spit (str out-path "/" filename) serialized :append true))
              (catch Exception ex
                (error "Exception" ex "when parsing line:\n" line))))
          (info filename "-" (count @ts-uuids) "entries," @line-count "lines"))))))

(defn filter-vclock [path out-path host-id]
  (let [files (file-seq (clojure.java.io/file path))
        ts-uuids (atom #{})
        line-count (atom 0)
        files (f/filter-by-name files #"\d{4}-\d{2}-\d{2}a?.jrn")
        sorted-files (sort-by #(.getName %) files)]
    (fs/mkdirs out-path)
    (doseq [f sorted-files]
      (with-open [reader (clojure.java.io/reader f)]
        (let [filename (.getName f)
              lines (line-seq reader)]
          (doseq [line lines]
            (try
              (swap! line-count inc)
              (let [entry (clojure.edn/read-string line)
                    id (:timestamp entry)
                    entry (if (:habit entry)
                            (let [criteria (get-in entry [:habit :criteria])]
                              (-> entry
                                  (assoc-in [:habit :versions 0 :criteria] criteria)
                                  (assoc-in [:habit :versions 0 :valid_from] "1970-01-01")))
                            entry)
                    serialized (str (pr-str entry) "\n")]
                (when-not (get-in entry [:vclock host-id])
                  (swap! ts-uuids conj id)
                  (spit (str out-path "/" filename) serialized :append true)))
              (catch Exception ex
                (error "Exception" ex "when parsing line:\n" line))))
          (info filename "-" (count @ts-uuids) "entries," @line-count "lines"))))))

;(m/migrate-to-dgraph "./data/migrations/dgraph")
#_(defn migrate-to-dgraph [path]
    (let [files (file-seq (clojure.java.io/file path))
          ts-uuids (atom #{})
          line-count (atom 0)
          files (f/filter-by-name files #"\d{4}-\d{2}-\d{2}a?.jrn")
          sorted-files (sort-by #(.getName %) files)
          channel (-> (ManagedChannelBuilder/forAddress "localhost" 9080)
                      (.usePlaintext true)
                      (.build))
          stub (DgraphGrpc/newStub channel)
          dgraph-client (new DgraphClient (into-array [stub]))]
      (doseq [f sorted-files]
        (with-open [reader (clojure.java.io/reader f)]
          (let [filename (.getName f)
                lines (line-seq reader)]
            (doseq [line lines]
              (swap! line-count inc)
              (when (zero? (mod @line-count 100)) (prn @line-count))
              (try
                (let [entry (clojure.edn/read-string line)
                      id (:timestamp entry)
                      entry (if (:habit entry)
                              (let [criteria (get-in entry [:habit :criteria])]
                                (-> entry
                                    (assoc-in [:habit :versions 0 :criteria] criteria)
                                    (assoc-in [:habit :versions 0 :valid_from] "1970-01-01")))
                              entry)]
                  (try
                    (let [entry (-> entry
                                    (update :sample pr-str)
                                    (update :habit pr-str)
                                    (update :geoname pr-str)
                                    (dissoc :id)
                                    (update :questionnaires pr-str)
                                    (update :linked_entries #(filter identity %))
                                    (update :linked_stories #(filter identity %))
                                    (update :vclock pr-str)
                                    (update :spotify pr-str)
                                    (update :custom_fields pr-str))
                          json (cc/generate-string entry)
                          mu (-> (DgraphProto$Mutation/newBuilder)
                                 (.setSetJson (ByteString/copyFromUtf8 json))
                                 (.build))
                          txn (.newTransaction dgraph-client)]
                      (.mutate txn mu)
                      (.commit txn))
                    (catch Exception ex (prn :error ex entry)))
                  (swap! ts-uuids conj id))
                (catch Exception ex
                  (do (prn :error ex) (error "Exception" ex "when parsing line:\n" line)))))
            (info filename "-" (count @ts-uuids) "entries," @line-count "lines"))))
      (.shutdown channel)))
