(ns meins.misc-utils-test
  "Here, we test some helpter functions. These tests are written in cljc and
   can also run on the JVM, as we only have pure punctions in the target
   namespace."
  (:require #?(:clj  [clojure.test :refer [deftest is testing]]
               :cljs [cljs.test :refer [deftest is testing]])
            [meins.common.utils.misc :as u]
            [meins.jvm.file-utils :as fu]))

(deftest duration-string-test
  (testing "test output for some different durations"
    (is (= (u/duration-string 0) ""))
    (is (= (u/duration-string 11) "11s"))
    (is (= (u/duration-string 111) "1m 51s"))
    (is (= (u/duration-string 1111) "18m 31s"))
    (is (= (u/duration-string 11111) "3h 5m 11s"))
    (is (= (u/duration-string 111111) "30h 51m 51s"))
    (is (= (u/duration-string 7931.999999999999) "2h 12m 11s"))))

(deftest double-ts-to-long-test
  (testing "correctly converts number"
    (is (= 100000 (u/double-ts-to-long 100))))
  (testing "converted number is of correct type"
    (is (= (type (u/double-ts-to-long 100)) #?(:clj  java.lang.Long
                                               :cljs js/Number))))
  (testing "calling with other than number results in nil"
    (is (nil? (u/double-ts-to-long nil)))
    (is (nil? (u/double-ts-to-long "123")))))

(def completed-entry
  {:arrival-date        "2016-08-16 11:29:41 +0000"
   :departure-date      "2016-08-16 16:33:19 +0000"
   :tags                #{"#visit" "#import"}
   :departure_timestamp 1.471365199000049E9
   :arrival_timestamp   1.471346981391931E9
   :horizontal-accuracy 29.1
   :type                "visit"
   :longitude           10.0
   :latitude            53.0
   :device              "iPhone"
   :timestamp           1471346981391
   :md                  "Duration: 303.6m #visit"})

(deftest visit-timestamps-test
  (testing "entry with completed visit parsed correctly"
    (is (= {:arrival_ts   1471346981391
            :departure_ts 1471365199000}
           (u/visit-timestamps completed-entry))))
  (testing "entry without visit parsed correctly"
    (is (= {:arrival_ts   nil
            :departure_ts nil}
           (u/visit-timestamps (-> completed-entry
                                   (dissoc :arrival_timestamp)
                                   (dissoc :departure_timestamp))))))
  (testing "entry with incomplete visit parsed correctly"
    (is (= {:arrival_ts   1471346981391
            :departure_ts nil}
           (u/visit-timestamps (merge completed-entry
                                      {:departure_timestamp 64092211200}))))))

(deftest deep-merge-test
  (testing "maps are merged properly"
    (is (= {:a {:b {:c 2
                    :d 2}}
            :b 2}
           (u/deep-merge {:a {:b {:c 1
                                  :d 2}}
                          :b 1}
                         {:b 2}
                         {:a {:b {:c 2}}}))))
  (testing "handles nil properly"
    (is (= (u/deep-merge nil nil nil)
           nil))
    (is (= (u/deep-merge nil {:a 1})
           {:a 1}))
    (is (= (u/deep-merge {:a 1} nil nil)
           {:a 1}))))

(deftest count-words-test
  (testing "counts words properly"
    (is (= 69
           (u/count-words {:md "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum  "}))))
  (testing "counts words properly when word at beginning of line"
    (is (= 29
           (u/count-words {:md "Alabama \nArizona\nCalifornia\nColorado\nConnecticut\nDelaware\nDistrictOfColumbia\nFlorida\nIllinois\nLouisiana\nMaine\nMaryland\nMassachussets\nMississippi \nNevada\nNew Hampshire\nNew Jersey\nNew York\nOregon\nPennsylvania\nRhode Island\nUtah\nVermont\nVirgina\nWashington\n\n"})))))

(def clean-test-entry
  {:mentions         #{},
   :tags             #{"#PSS"}
   :linked-stories   #{}
   :timezone         "CET"
   :utc_offset       -60
   :new-entry        true
   :pomodoro-running true
   :longitude        12.3
   :planned_dur      1500
   :comment_for      1517587606253
   :last_saved       1517602023551
   :vclock           {"edf3da73-f8e7-4076-8387-bfb35b7999e1" 77}
   :latitude         51.5
   :editor-state     {:entityMap {}
                      :blocks    [{:key          "5peo9"
                                   :text         "fixing the faulty implementation"
                                   :type         "unordered-list-item"
                                   :depth        0 :inlineStyleRanges []
                                   :entityRanges []
                                   :data         {}}]}
   :completed_time   2040
   :timestamp        1517589827814
   :text             "fixing the faulty implementation"
   :md               "- fixing the faulty implementation"})

(deftest clean-entry-test
  (testing "expected keys are removed"
    (is (= {:comment_for    1517587606253
            :completed_time 2040
            :latitude       51.5
            :linked-stories #{}
            :longitude      12.3
            :md             "- fixing the faulty implementation"
            :mentions       #{}
            :planned_dur    1500
            :tags           #{"#PSS"}
            :task           nil
            :text           "fixing the faulty implementation"
            :timestamp      1517589827814
            :timezone       "CET"
            :utc_offset     -60}
           (u/clean-entry clean-test-entry)))))

(def app-cfg
  {:server {:hostname "host"
            :password "password"
            :username "user"
            :port     993}
   :sync   {:write {:folder "INBOX.mobile-write"}
            :read  {:folder "INBOX.desktop-write"}}})

(def imap-cfg
  {:server {:host        "host"
            :password    "password"
            :user        "user"
            :authTimeout 15000
            :connTimeout 30000
            :port        993
            :autotls     true
            :tls         true}
   :sync   {:write {:mailbox "INBOX.desktop-write"
                    :secret  "secret"}
            :read  {:fred
                    {:mailbox   "INBOX.mobile-write"
                     :body-part "1"
                     :secret    "secret"
                     :last-read 1}}}})

(deftest imap-to-app-cfg-test
  (testing "converts imap config as required by app"
    (is (= app-cfg (u/imap-to-app-cfg imap-cfg)))))
