(ns meins.shared.import-test
  (:require [cljs.test :refer [deftest testing is]]
            [meins.electron.main.import.audio :as ai]
            [meins.common.specs]
            [meins.electron.main.helpers :as h]
            [cljs.spec.alpha :as s]
            [cljs.pprint :as pp]
            [clojure.data :as data]
            [meins.electron.main.import.images :as ii]
            [meins.electron.main.import.measurement :as im]
            [meins.electron.main.import.text :as it]
            [meins.electron.main.import.health :as ih]
            [meins.electron.main.import.survey :as is]))

(defn test-data-file [file]
  (str "./src/test/meins/shared/test-files/" file))

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
  (let [json-file (test-data-file "test1.aac.json")
        data (h/parse-json json-file)
        entry (ai/convert-audio-entry data)]
    (testing "JSON is parsed correctly"
      (is (= entry test-entry)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))

(def expected-text2 (str (h/format-time 1636326416054) " Audio"))
(def new-audio-test-entry
  {:mentions   #{}
   :timezone   "Europe/Berlin"
   :utc-offset 60
   :timestamp  1636326416054
   :audio_file "2021-11-07_23-06-56-054.aac"
   :md         expected-text2
   :text       expected-text2
   :tags       #{"#import" "#audio"}
   :perm_tags  #{"#audio" "#task"}
   :longitude  9
   :latitude   53
   :vclock     {"bae5c26c-1580-4df1-a1e7-cb40a81444f7" 13}})

(deftest read-new-audio-entry-test
  (let [json-file (test-data-file "test2.aac.json")
        data (h/parse-json json-file)
        entry (ai/convert-new-audio-entry data)]
    (testing "JSON is parsed correctly"
      (is (= entry new-audio-test-entry)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))

(def new-audio-test-entry-with-text
  {:mentions   #{}
   :timezone   "Europe/Berlin"
   :utc-offset 60
   :timestamp  1636326416054
   :audio_file "2021-11-07_23-06-56-054.aac"
   :text       "Blah \nFoo\nBar\nBaz \n"
   :md         "# Blah \n\n* Foo\n* Bar\n* Baz \n"
   :tags       #{"#import" "#audio"}
   :perm_tags  #{"#audio" "#task"}
   :longitude  9
   :latitude   53
   :vclock     {"bae5c26c-1580-4df1-a1e7-cb40a81444f7" 13}})

(deftest read-new-audio-entry-test-with-text
  (let [json-file (test-data-file "test3.aac.json")
        data (h/parse-json json-file)
        entry (ai/convert-new-audio-entry data)]
    (testing "JSON is parsed correctly"
      (is (= entry new-audio-test-entry-with-text)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))

(def time-recording-test-entry
  {:timezone       "Europe/Berlin"
   :utc-offset     60
   :longitude      9
   :entry_type     :pomodoro
   :comment_for    1636326416054
   :latitude       53
   :completed_time 1.026
   :timestamp      1636326417054
   :text           "recording"
   :md             "- recording"})

(deftest time-recording-entry-test
  (let [json-file (test-data-file "test2.aac.json")
        data (h/parse-json json-file)
        entry (ai/time-recording-entry data)]
    (testing "JSON is parsed correctly"
      (is (= entry time-recording-test-entry)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))

(def expected-text3 (str (h/format-time 1636319781000) " Image"))
(def new-image-test-entry
  {:mentions   #{}
   :timezone   "Europe/Berlin"
   :utc-offset 0
   :timestamp  1636319781000
   :img_file   "E5CC2467-56F0-4CA4-A168-EA6719091D76.IMG_7524.JPG"


   :md         expected-text3
   :text       expected-text3
   :tags       #{"#import" "#photo"}
   :perm_tags  #{"#photo"}
   :longitude  9
   :latitude   53
   :vclock     {"bae5c26c-1580-4df1-a1e7-cb40a81444f7" 4}})

(deftest read-new-image-entry-test
  (let [json-file (test-data-file "test.HEIC.json")
        data (h/parse-json json-file)
        entry (ii/convert-new-image-entry data)]
    (testing "JSON is parsed correctly"
      (is (= entry new-image-test-entry)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))

(deftest survey-import-cfq11-test
  (let [json-file (test-data-file "cfq11_test_entry.json")
        input-data (h/parse-json json-file)
        expected (h/parse-edn (test-data-file "cfq11_test_entry_converted.edn"))
        entry (is/convert-survey input-data)]
    (testing "Survey JSON is parsed correctly"
      (is (= entry expected)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))

(deftest survey-import-panas-test
  (let [json-file (test-data-file "panas_test_entry.json")
        input-data (h/parse-json json-file)
        expected (h/parse-edn (test-data-file "panas_test_entry_converted.edn"))
        entry (is/convert-survey input-data)]
    (testing "Survey JSON is parsed correctly"
      (is (= entry expected)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))

(deftest steps-import-test
  (let [json-file (test-data-file "steps_test_entry.json")
        input (h/parse-json json-file)
        expected (h/parse-edn (test-data-file "steps_test_entry_converted.edn"))
        entry (ih/convert-steps-entry input)]
    (testing "Survey JSON is parsed correctly"
      (is (= entry expected)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))

(deftest weight-import-test
  (let [json-file (test-data-file "weight_test_entry.json")
        input (h/parse-json json-file)
        expected (h/parse-edn (test-data-file "weight_test_entry_converted.edn"))
        entry (ih/convert-weight-entry input)]
    (testing "Survey JSON is parsed correctly"
      (is (= entry expected)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))

(deftest bodyfat-import-test
  (let [json-file (test-data-file "bf_test_entry.json")
        input (h/parse-json json-file)
        expected (h/parse-edn (test-data-file "bf_test_entry_converted.edn"))
        entry (ih/convert-bodyfat-entry input)]
    (testing "Survey JSON is parsed correctly"
      (is (= entry expected)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))

(deftest sleep-import-test
  (let [json-file (test-data-file "sleep_test_entry.json")
        input (h/parse-json json-file)
        expected (h/parse-edn (test-data-file "sleep_test_entry_converted.edn"))
        entry (ih/convert-sleep-entry input)]
    (testing "Survey JSON is parsed correctly"
      (is (= entry expected)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))

(deftest bp-diastolic-import-test
  (let [json-file (test-data-file "bp_diastolic_test_entry.json")
        input (h/parse-json json-file)
        expected (h/parse-edn (test-data-file "bp_diastolic_test_entry_converted.edn"))
        entry (ih/convert-bp-entry-diastolic input)]
    (testing "Survey JSON is parsed correctly"
      (is (= entry expected)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))

(deftest bp-systolic-import-test
  (let [json-file (test-data-file "bp_systolic_test_entry.json")
        input (h/parse-json json-file)
        expected (h/parse-edn (test-data-file "bp_systolic_test_entry_converted.edn"))
        entry (ih/convert-bp-entry-systolic input)]
    (testing "Survey JSON is parsed correctly"
      (is (= entry expected)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))

(deftest text-entry-import-test
  (let [json-file (test-data-file "text_test_entry.json")
        input (h/parse-json json-file)
        expected (h/parse-edn (test-data-file "text_test_entry_converted.edn"))
        entry (it/convert-text-entry input)]
    (testing "Text entry JSON is parsed correctly"
      (is (= entry expected)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))

(deftest measurement-entry-import-test
  (let [json-file (test-data-file "test.measurement.json")
        input (h/parse-json json-file)
        expected (h/parse-edn (test-data-file "test.measurement.converted.edn"))
        entry (im/convert-measurement-entry input)]
    (testing "Measurement entry JSON is parsed correctly"
      (is (= entry expected)))
    (testing "Parsed entry is valid"
      (s/valid? :meins.entry/spec entry))))
