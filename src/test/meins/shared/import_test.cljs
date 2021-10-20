(ns meins.shared.import-test
  (:require [cljs.test :refer [deftest testing is]]
            [meins.electron.main.import :as emi]
            [meins.common.specs]
            [meins.electron.main.helpers :as h]
            [cljs.spec.alpha :as s]))

(def expected-text (str (h/format-time 1634044303702) " Audio"))

(def test-entry
  {:mentions   #{}
   :timezone   "Europe/Berlin"
   :utc-offset 120
   :timestamp  1634044303702
   :audio_file "2021-10-12_15-11-43-702.aac"
   :md         expected-text
   :text       expected-text
   :tags       #{"#import" "#audio"}
   :perm_tags  #{"#audio" "#task"}
   :longitude  13
   :latitude   52
   :vclock     {"1231bb84-da9b-4abe-b0ab-b300349818af" 28}})

(deftest read-entry-test
  (let [json-file "./src/test/meins/shared/audio/2021-10-12/2021-10-12_15-11-43-702.aac.json"
        data (emi/parse-json json-file)
        entry (emi/convert-entry data)]
    (testing "JSON is parsed correctly"
      (is (= entry test-entry)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))
