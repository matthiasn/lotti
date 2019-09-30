(ns meins.playground-test
  (:require [clojure.string :as s]
            [clojure.test :refer :all]
            [meins.jvm.playground :as pg]
            [taoensso.timbre :refer [error info warn]]))

(def parsed-file (pg/parse-txt "bfaut11.txt" Integer/MAX_VALUE))

(deftest parse-txt-text
  (testing "split file into correct number of entries"
    (is (= 635 (count parsed-file))))
  (testing "first two entries read correctly"
    (is (= (take 2 (pg/parse-txt "bfaut11.txt" 50))
           [{:md       "The Project #Gutenberg EBook of The Autobiography of Benjamin Franklin by Benjamin Franklin"
             :mentions #{}
             :tags     #{"#Gutenberg"}}
            {:md       "Copyright laws are changing all over the world. Be sure to check the #copyright laws for your country before downloading or redistributing this or any other Project #Gutenberg eBook."
             :mentions #{}
             :tags     #{"#Gutenberg" "#copyright"}}])))
  (testing "replaces tags correctly"
    (is (= 53
           (count (filter #(s/includes? % "#Philadelphia")
                          parsed-file)))))
  (testing "replaces mentions correctly"
    (is (= 40
           (count (filter #(s/includes? % "@father")
                          parsed-file))))))

(def generated-entries (pg/add-timestamps parsed-file))

(deftest add-timestamps-test
  (testing "timestamp is set for all generated entries"
    (is (every? #(integer? (:timestamp %)) generated-entries)))
  (testing "last entry is newer than first entry"
    (is (> (-> generated-entries last :timestamp)
           (-> generated-entries first :timestamp)))))