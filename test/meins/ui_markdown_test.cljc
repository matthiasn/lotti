(ns meins.ui-markdown-test
  "Here, we test the markdown UI functions. These tests are written in cljc and can also run on the JVM,
  as we only have pure punctions in the target namespace."
  (:require #?(:clj [clojure.test :refer [deftest is testing]]
               :cljs [cljs.test :refer [deftest is testing]])
    ;[meins.jvm.ui.markdown :as m]
                    ))

(def test-entry
  {:mentions   #{}
   :tags       #{"#cljc"}
   :timezone   "Europe/Berlin"
   :utc-offset -120
   :timestamp  1465059173965
   :md         "Moving to #cljc"})

(def test-entry2
  {:mentions   #{"@myself"}
   :tags       #{"#task" "#UI" "#pomodoros" "#interacting" "#events" "#pomodoro" "#timestamp"}
   :timezone   "Europe/Berlin"
   :utc-offset -120
   :longitude  9.9
   :upvotes    4
   :latitude   53.1
   :timestamp  1464643281098
   :md         "New #task: count the time spent #interacting with the #UI when no #pomodoro is running. Mouse-over and key #events should be a good indicator for that. When nothing happens longer than x, don't extend the current period of activity but rather close the last one at the last #timestamp and create a new period of activity. I like that. Not all work can possibly happen in #pomodoros, and it would be a waste of data to not capture that time. @myself "})

(def test-entry3
  {:mentions   #{}
   :tags       #{"#unordered-list"}
   :timezone   "Europe/Berlin"
   :utc-offset -120
   :longitude  9.9
   :latitude   53.1
   :timestamp  1465263270878
   :md         "Some test with #unordered-list:\n\n* line 1\n* line 2\n* line 3\n* line 4\n"})

(def test-entry4
  {:mentions   #{}
   :tags       #{"#tag1" "#tag2" "#tag3"}
   :timezone   "Europe/Berlin"
   :utc-offset -120
   :timestamp  1465059173965
   :md         "This test case is to prevent a regression where multiple hashtags in a row were not properly formatted. #tag1 #tag2 #tag3"})

(def test-entry5
  {:mentions   #{}
   :tags       #{"#formatting" "#format"}
   :timezone   "Europe/Berlin"
   :utc-offset -120
   :timestamp  1465059173965
   :md         "This test case is to prevent a regression where the #formatting was messed if one tag was a substring of another. #format"})

(def cfg-show-hashtags
  {:hide-hashtags   false
   :lines-shortened 1})

(def cfg-hide-hashtags
  {:hide-hashtags   true
   :lines-shortened 1})

(defn third [x] (first (nnext x)))
(defn toggle-edit [])

;; TODO: this should probably be revived

#_
(deftest markdown-render-test
  ""
  (testing "renders test-entry as expected, with #"
    (is (= (third ((m/markdown-render test-entry cfg-show-hashtags toggle-edit)
                    test-entry cfg-show-hashtags toggle-edit))
           [:div {:dangerouslySetInnerHTML {:__html "<p>Moving to <a href='/##cljc'>#cljc</a></p>"}}])))

  (testing "renders test-entry as expected, without #"
    (is (= (third ((m/markdown-render test-entry cfg-hide-hashtags toggle-edit)
                    test-entry cfg-hide-hashtags toggle-edit))
           [:div {:dangerouslySetInnerHTML {:__html "<p>Moving to <a href='/##cljc'>cljc</a></p>"}}])))

  (testing "renders more complex test-entry2 as expected, with #"
    (is (= (third ((m/markdown-render test-entry2 cfg-show-hashtags toggle-edit)
                    test-entry2 cfg-show-hashtags toggle-edit))
           [:div {:dangerouslySetInnerHTML {:__html "<p>New <a href='/##task'>#task</a>: count the time spent <a href='/##interacting'>#interacting</a> with the <a href='/##UI'>#UI</a> when no <a href='/##pomodoro'>#pomodoro</a> is running. Mouse-over and key <a href='/##events'>#events</a> should be a good indicator for that. When nothing happens longer than x, don't extend the current period of activity but rather close the last one at the last <a href='/##timestamp'>#timestamp</a> and create a new period of activity. I like that. Not all work can possibly happen in <a href='/##pomodoros'>#pomodoros</a>, and it would be a waste of data to not capture that time.  <a class='mention-link' href='/#@myself'>@myself</a> </p>"}}])))

  (testing "renders more complex test-entry2 as expected, without #"
    (is (= (third ((m/markdown-render test-entry2 cfg-hide-hashtags toggle-edit)
                    test-entry2 cfg-hide-hashtags toggle-edit))
           [:div {:dangerouslySetInnerHTML {:__html "<p>New <a href='/##task'>task</a>: count the time spent <a href='/##interacting'>interacting</a> with the <a href='/##UI'>UI</a> when no <a href='/##pomodoro'>pomodoro</a> is running. Mouse-over and key <a href='/##events'>events</a> should be a good indicator for that. When nothing happens longer than x, don't extend the current period of activity but rather close the last one at the last <a href='/##timestamp'>timestamp</a> and create a new period of activity. I like that. Not all work can possibly happen in <a href='/##pomodoros'>pomodoros</a>, and it would be a waste of data to not capture that time.  <a class='mention-link' href='/#@myself'>myself</a> </p>"}}])))

  (testing "renders unordered list in test-entry3 as expected, first line only"
    (is (= (third ((m/markdown-render test-entry3 cfg-show-hashtags toggle-edit)
                    test-entry3 cfg-show-hashtags toggle-edit))
           [:div {:dangerouslySetInnerHTML {:__html "<p>Some test with <a href='/##unordered-list'>#unordered-list</a>:</p>"}}])))

  (testing "renders unordered list in test-entry3 as expected, all lines"
    (with-redefs [m/initial-atom (atom false)]
      (is (= (third ((m/markdown-render test-entry3 cfg-show-hashtags toggle-edit)
                      test-entry3 cfg-show-hashtags toggle-edit))
             [:div {:dangerouslySetInnerHTML {:__html "<p>Some test with <a href='/##unordered-list'>#unordered-list</a>:</p><ul><li>line 1</li><li>line 2</li><li>line 3</li><li>line 4</li></ul>"}}]))))

  (testing "multiple hashtags in a row are rendered correctly"
    (is (= (third ((m/markdown-render test-entry4 cfg-show-hashtags toggle-edit)
                    test-entry4 cfg-show-hashtags toggle-edit))
           [:div {:dangerouslySetInnerHTML {:__html "<p>This test case is to prevent a regression where multiple hashtags in a row were not properly formatted. <a href='/##tag1'>#tag1</a> <a href='/##tag2'>#tag2</a> <a href='/##tag3'>#tag3</a></p>"}}])))

  (testing "hashtags can be a substring of another hashtag"
    (is (= (third ((m/markdown-render test-entry5 cfg-show-hashtags toggle-edit)
                    test-entry5 cfg-show-hashtags toggle-edit))
           [:div {:dangerouslySetInnerHTML {:__html "<p>This test case is to prevent a regression where the <a href='/##formatting'>#formatting</a> was messed if one tag was a substring of another. <a href='/##format'>#format</a></p>"}}]))))