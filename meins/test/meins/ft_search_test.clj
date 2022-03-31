(ns meins.ft-search-test
  "Here, we test the handler functions of the fulltext search component."
  (:require [clojure.test :refer [deftest is testing]]
            [clucy.core :as clucy]
            [meins.jvm.fulltext-search :as fs]
            [meins.jvm.fulltext-search :as ft]))

(def some-test-entry
  {:mentions   #{"@SantaClaus"}
   :tags       #{"#test" "#xmas"}
   :timezone   "Europe/Berlin"
   :utc-offset -120
   :longitude  9.9999
   :latitude   53.112233
   :timestamp  1450998000000
   :md         "Some test entry"})

(deftest entry-index-test
  (with-redefs [ft/index (clucy/memory-index)]
    (testing "entry is added"
      (fs/add-to-index {:msg-payload some-test-entry})
      (is (= [1450998000000]
             (fs/search {:ft-search "test"}))))
    (testing "entry is removed"
      (fs/remove-from-index {:msg-payload {:timestamp 1450998000000}})
      (is (= []
             (fs/search {:ft-search "test"}))))))

(deftest cmp-map-test
  (testing "cmp-map contains required keys"
    (let [cmp-id :server/ft-cmp
          cmp-map (fs/cmp-map cmp-id)
          handler-map (:handler-map cmp-map)]
      (is (= (:cmp-id cmp-map) cmp-id))
      (is (fn? (:ft/add handler-map)))
      (is (fn? (:ft/remove handler-map))))))
