(ns meins.shared.import-test
  (:require [cljs.test :refer [deftest testing is]]
            [meins.electron.main.import.audio :as ai]
            [meins.common.specs]
            [meins.electron.main.helpers :as h]
            [cljs.spec.alpha :as s]
            [cljs.pprint :as pp]))

(def test-entry
  {:mentions   #{}
   :timezone   "Europe/Berlin"
   :utc-offset 120
   :timestamp  1634044303702
   :audio_file "2021-10-12_15-11-43-702.aac"
   :md         "2021-10-12 15:11 Audio"
   :text       "2021-10-12 15:11 Audio"
   :tags       #{"#import" "#audio"}
   :perm_tags  #{"#audio" "#task"}
   :longitude  13
   :latitude   52
   :vclock     {"1231bb84-da9b-4abe-b0ab-b300349818af" 28}})

(deftest read-entry-test
  (let [json-file "./src/test/meins/shared/audio/2021-10-12/2021-10-12_15-11-43-702.aac.json"
        data (h/parse-json json-file)
        entry (ai/convert-audio-entry data)]
    (testing "JSON is parsed correctly"
      (is (= entry test-entry)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))

(def new-audio-test-entry
  {:mentions   #{}
   :timezone   "Europe/Berlin"
   :utc-offset 60
   :timestamp  1636205326587
   :audio_file "2021-11-06_14-28-41-728.aac"
   :md         "2021-11-06 14:28 Audio"
   :text       "2021-11-06 14:28 Audio"
   :tags       #{"#import" "#audio"}
   :perm_tags  #{"#audio" "#task"}
   :longitude  13
   :latitude   52
   :vclock     {"1231bb84-da9b-4abe-b0ab-b300349818af" 37}})

(deftest read-new-audio-entry-test
  (let [json-file "./src/test/meins/shared/audio/2021-11-06/2021-11-06_14-28-41-728.aac.json"
        data (h/parse-json json-file)
        entry (ai/convert-new-audio-entry data)]
    (prn "data")
    (pp/pprint data)
    (prn "entry")
    (pp/pprint entry)
    (testing "JSON is parsed correctly"
      (is (= entry new-audio-test-entry)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))
