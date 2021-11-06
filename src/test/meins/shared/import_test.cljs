(ns meins.shared.import-test
  (:require [cljs.test :refer [deftest testing is]]
            [meins.electron.main.import.audio :as ai]
            [meins.common.specs]
            [meins.electron.main.helpers :as h]
            [cljs.spec.alpha :as s]
            [cljs.pprint :as pp]
            [meins.electron.main.import.images :as ii]))

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
  (let [json-file "./src/test/meins/shared/test-json/2021-10-12_15-11-43-702.aac.json"
        data (h/parse-json json-file)
        entry (ai/convert-audio-entry data)]
    (testing "JSON is parsed correctly"
      (is (= entry test-entry)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))

(def expected-text2 (str (h/format-time 1636208921728) " Audio"))
(def new-audio-test-entry
  {:mentions   #{}
   :timezone   "Europe/Berlin"
   :utc-offset 60
   :timestamp  1636208921728
   :audio_file "2021-11-06_14-28-41-728.aac"
   :md         expected-text2
   :text       expected-text2
   :tags       #{"#import" "#audio"}
   :perm_tags  #{"#audio" "#task"}
   :longitude  13
   :latitude   52
   :vclock     {"1231bb84-da9b-4abe-b0ab-b300349818af" 37}})

(deftest read-new-audio-entry-test
  (let [json-file "./src/test/meins/shared/test-json/2021-11-06_14-28-41-728.aac.json"
        data (h/parse-json json-file)
        entry (ai/convert-new-audio-entry data)]
    (testing "JSON is parsed correctly"
      (is (= entry new-audio-test-entry)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))

(def time-recording-test-entry
  {:timezone       "Europe/Berlin"
   :utc-offset     60
   :longitude      13
   :entry_type     :pomodoro
   :comment_for    1636208921728
   :latitude       52
   :completed_time 4.027
   :timestamp      1636208922728
   :text           "recording"
   :md             "- recording"})

(deftest time-recording-entry-test
  (let [json-file "./src/test/meins/shared/test-json/2021-11-06_14-28-41-728.aac.json"
        data (h/parse-json json-file)
        entry (ai/time-recording-entry data)]
    (testing "JSON is parsed correctly"
      (is (= entry time-recording-test-entry)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))

(def expected-text3 (str (h/format-time 1636165154000) " Image"))
(def new-image-test-entry
  {:mentions   #{}
   :timezone   "Europe/Berlin"
   :utc-offset 0
   :timestamp  1636165154000
   :img_file   "A5E070A4-40A8-4BF0-A0B2-B368BA8A4232.IMG_7493.JPG"
   :md         expected-text3
   :text       expected-text3
   :tags       #{"#import" "#photo"}
   :perm_tags  #{"#photo"}
   :longitude  10
   :latitude   53
   :vclock     {"e961a1b8-c86d-402f-a282-f2752a3b6f09" 16}})

(deftest read-new-image-entry-test
  (let [json-file "./src/test/meins/shared/test-json/A5E070A4-40A8-4BF0-A0B2-B368BA8A4232.IMG_7493.HEIC.json"
        data (h/parse-json json-file)
        entry (ii/convert-new-image-entry data)]
    (testing "JSON is parsed correctly"
      (is (= entry new-image-test-entry)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))
