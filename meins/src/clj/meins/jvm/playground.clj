(ns meins.jvm.playground
  (:require [clojure.java.io :as io]
            [clojure.string :as s]
            [matthiasn.systems-toolbox.component :as st]
            [meins.common.utils.parse :as p]
            [meins.jvm.file-utils :as fu]))

(defn parse-txt [file n]
  (let [f (io/resource (str "playground/" file))
        acc (atom "")
        entries (atom [])]
    (with-open [reader (io/reader f)]
      (let [lines (take n (line-seq reader))]
        (doseq [line lines]
          (if (empty? line)
            (let [text (-> (s/trim @acc)
                           (s/replace "Gutenberg" "#Gutenberg")
                           (s/replace "copyright" "#copyright")
                           (s/replace "Philadelphia" "#Philadelphia")
                           (s/replace "Pennsylvania" "#Pennsylvania")
                           (s/replace "Boston" "#Boston")
                           (s/replace "London" "#London")
                           (s/replace "British" "#British")
                           (s/replace "Breintnal" "@Breintnal")
                           (s/replace "Braddock" "@Braddock")
                           (s/replace "Dunbar" "@Dunbar")
                           (s/replace "Denny" "@Denny")
                           (s/replace "Morris" "@Morris")
                           (s/replace "Keimer" "@Keimer")
                           (s/replace "Meredith" "@Meredith")
                           (s/replace "Bradford" "@Bradford")
                           (s/replace "Loudon" "@Loudon")
                           (s/replace "Whitefield" "@Whitefield")
                           (s/replace "Keith" "@Keith")
                           (s/replace " father" " @father")
                           (s/replace " grandfather" " @grandfather"))
                  parsed (p/parse-entry text)]
              (swap! entries conj parsed)
              (reset! acc ""))
            (let [t (s/trim line)]
              (swap! acc str t " "))))))
    @entries))

(defn add-timestamps [entries]
  (let [now (st/now)
        entries (map-indexed (fn [idx v] [idx v]) entries)
        interval (* 180 24 60 60 1000)
        gap (int (Math/floor (/ interval (count entries))))
        start (- now interval)
        f (fn [[i entry]] (assoc entry :timestamp (+ start (* i gap))))]
    (map f entries)))

(defn generate-entries [{:keys [put-fn]}]
  (when (s/includes? fu/data-path "playground")
    (let [parsed-file (parse-txt "bfaut11.txt" Integer/MAX_VALUE)
          generated-entries (add-timestamps parsed-file)]
      (doseq [entry generated-entries]
        (put-fn (with-meta [:entry/update entry] {:silent true}))))
    (put-fn [:gql/run-registered]))
  {})

(defn cmp-map [cmp-id]
  {:cmp-id      cmp-id
   :handler-map {:playground/gen generate-entries}})
