(ns meins.shared.import-test
  (:require [cljs.test :refer [deftest testing is]]
            [meins.electron.main.import :as emi]
            [meins.common.specs]
            [cljs.spec.alpha :as s]))

(def test-entry
  {:mentions   #{}
   :timezone   "Europe/Berlin"
   :utc-offset 120
   :timestamp  1634044303702
   :md         ""
   :text       ""
   :tags       #{"#import" "#audio"}
   :perm_tags  #{"#audio"}
   :lng        13
   :lat        52
   :vclock     {"1231bb84-da9b-4abe-b0ab-b300349818af" 28}})

(deftest read-entry-test
  (let [parsed (emi/read-entry "./src/test/meins/shared/audio/2021-10-12/2021-10-12_15-11-43-702.aac.json")]
    (testing "JSON is parsed correctly"
      (is (= parsed test-entry)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec parsed))))

(deftest list-dir-test
  (let []
    (testing "output is of expected type"
      (emi/list-dir "./src/test"))))
