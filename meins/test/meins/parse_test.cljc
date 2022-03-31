(ns meins.parse-test
  "Here, we test the parsing functions."
  (:require #?(:clj  [clojure.test :refer [deftest is testing]]
               :cljs [cljs.test :refer [deftest is testing]])
            [matthiasn.systems-toolbox.component :as stc]
            [meins.common.utils.parse :as p]))

(def n 25)

(def empty-entry
  {:mentions #{}
   :tags     #{}
   :md       ""})

(def test-entry
  {:mentions #{}
   :tags     #{"#cljc"}
   :md       "Moving to #cljc"})

(def test-entry2
  {:mentions #{"@myself"}
   :tags     #{"#task" "#UI" "#pomodoros" "#interacting" "#events" "#pomodoro" "#timestamp"}
   :md       "New #task: count the time spent #interacting with the #UI when no #pomodoro is running. Mouse-over and key #events should be a good indicator for that. When nothing happens longer than x, don't extend the current period of activity but rather close the last one at the last #timestamp and create a new period of activity. I like that. Not all work can possibly happen in #pomodoros, and it would be a waste of data to not capture that time. @myself"})

(def test-entry3
  {:mentions #{"@myself" "@JohnDoe"}
   :tags     #{"#tag1" "#tag2" "#tag3"}
   :md       "#tag1 #tag2 #tag3 @JohnDoe @myself"})

(def test-entry4
  {:mentions #{"@myself" "@JohnDoe"}
   :tags     #{"#tag1"}
   :md       "# foo bar headline #tag1 @JohnDoe @myself"})

(deftest parse-entry-test
  (testing "empty entry is parsed correctly"
    (is (= (p/parse-entry (:md empty-entry)) empty-entry)))
  (testing "test-entry is parsed correctly"
    (is (= (p/parse-entry (:md test-entry)) test-entry)))
  (testing "test-entry2 is parsed correctly"
    (is (= (p/parse-entry (:md test-entry2)) test-entry2)))
  (testing "test-entry3 is parsed correctly: # at beginning of line, too"
    (is (= (p/parse-entry (:md test-entry3)) test-entry3)))
  (testing "test-entry4 is parsed correctly: # in headline ignored"
    (is (= (p/parse-entry (:md test-entry4)) test-entry4))))


(def empty-search
  {:search-text ""
   :ft-search   nil
   :country     nil
   :tags        #{}
   :not-tags    #{}
   :mentions    #{}
   :opts        #{}
   :from        nil
   :to          nil
   :date_string nil
   :briefing    nil
   :timestamp   nil
   :id          nil
   :linked      nil
   :n           n})

(def fulltext-search
  {:search-text "'travel AND aircraft'"
   :ft-search   "travel AND aircraft"
   :country     nil
   :tags        #{}
   :not-tags    #{}
   :mentions    #{}
   :opts        #{}
   :from        nil
   :to          nil
   :date_string nil
   :briefing    nil
   :timestamp   nil
   :id          nil
   :linked      nil
   :n           n})

(def open-tasks-search
  {:search-text "#task ~#done ~#backlog ~#outdated"
   :ft-search   nil
   :country     nil
   :tags        #{"#task"}
   :not-tags    #{"#backlog" "#done" "#outdated"}
   :mentions    #{}
   :opts        #{}
   :from        nil
   :to          nil
   :date_string nil
   :briefing    nil
   :timestamp   nil
   :id          nil
   :linked      nil
   :n           n})

(def started-tasks-search
  {:search-text "#task ~#done ~#backlog ~#outdated :started"
   :ft-search   nil
   :country     nil
   :tags        #{"#task"}
   :not-tags    #{"#backlog" "#done" "#outdated"}
   :mentions    #{}
   :opts        #{":started"}
   :from nil
   :to nil
   :date_string nil
   :briefing    nil
   :timestamp   nil
   :id          nil
   :linked      nil
   :n           n})

(def tasks-done-search
  {:search-text "#task #done @myself"
   :ft-search   nil
   :country     nil
   :tags        #{"#task" "#done"}
   :not-tags    #{}
   :mentions    #{"@myself"}
   :opts        #{}
   :from nil
   :to nil
   :date_string nil
   :briefing    nil
   :timestamp   nil
   :id          nil
   :linked      nil
   :n           n})

(def day-search
  {:search-text "2016-06-07 #task #done @myself"
   :ft-search   nil
   :country     nil
   :tags        #{"#task" "#done"}
   :not-tags    #{}
   :mentions    #{"@myself"}
   :opts        #{}
   :date_string "2016-06-07"
   :from        nil
   :to          nil
   :briefing    nil
   :timestamp   nil
   :id          nil
   :linked      nil
   :n           n})

(def from-to-search
  {:search-text "f:2016-06-07 t:2018-06-07 #task #done @JohnDoe"
   :ft-search   nil
   :country     nil
   :tags        #{"#task" "#done"}
   :not-tags    #{}
   :mentions    #{"@JohnDoe"}
   :opts        #{}
   :date_string nil
   :from        "2016-06-07"
   :to          "2018-06-07"
   :briefing    nil
   :timestamp   nil
   :id          nil
   :linked      nil
   :n           n})

(def briefing-search
  {:search-text "b:2016-06-07"
   :ft-search   nil
   :country     nil
   :tags        #{}
   :not-tags    #{}
   :mentions    #{}
   :opts        #{}
   :from        nil
   :to          nil
   :date_string nil
   :briefing    "2016-06-07"
   :timestamp   nil
   :id          nil
   :linked      nil
   :n           n})

(def timestamp-search
  {:search-text "1465325998053"
   :ft-search   nil
   :country     nil
   :tags        #{}
   :not-tags    #{}
   :mentions    #{}
   :opts        #{}
   :from        nil
   :to          nil
   :date_string nil
   :briefing    nil
   :timestamp   "1465325998053"
   :linked      nil
   :id          nil
   :n           n})

(def linked-search
  {:search-text "l:1465325998053"
   :ft-search   nil
   :country     nil
   :tags        #{}
   :not-tags    #{}
   :mentions    #{}
   :opts        #{}
   :from        nil
   :to          nil
   :date_string nil
   :briefing    nil
   :timestamp   nil
   :linked      "1465325998053"
   :id          nil
   :n           n})

(def country-search
  {:search-text "cc:DE"
   :ft-search   nil
   :country     "DE"
   :tags        #{}
   :not-tags    #{}
   :mentions    #{}
   :opts        #{}
   :from        nil
   :to          nil
   :date_string nil
   :briefing    nil
   :timestamp   nil
   :linked      nil
   :id          nil
   :n           n})

(def id-search
  {:search-text "48cde500-0d4f-11e7-8d14-42a2f9d2d24d"
   :ft-search   nil
   :country     nil
   :tags        #{}
   :not-tags    #{}
   :mentions    #{}
   :opts        #{}
   :from        nil
   :to          nil
   :date_string nil
   :briefing    nil
   :timestamp   nil
   :linked      nil
   :id          "48cde500-0d4f-11e7-8d14-42a2f9d2d24d"
   :n           n})

(deftest parse-search-test
  (testing
    "empty query is parsed correctly"
    (is (= (p/parse-search (:search-text empty-search))
           empty-search)))

  (testing
    "open tasks query is parsed correctly"
    (is (= (p/parse-search (:search-text open-tasks-search))
           open-tasks-search)))

  (testing
    "tasks done query is parsed correctly"
    (is (= (p/parse-search (:search-text tasks-done-search))
           tasks-done-search)))

  (testing
    "fulltext search string is parsed correctly"
    (is (= (p/parse-search (:search-text started-tasks-search))
           started-tasks-search)))

  (testing
    "fulltext search string is parsed correctly"
    (is (= (p/parse-search (:search-text fulltext-search))
           fulltext-search)))

  (testing
    "day query is parsed correctly"
    (is (= (p/parse-search (:search-text day-search))
           day-search)))

  (testing
    "from to interval query is parsed correctly"
    (is (= (p/parse-search (:search-text from-to-search))
           from-to-search)))

  (testing
    "briefing for day query is parsed correctly"
    (is (= (p/parse-search (:search-text briefing-search))
           briefing-search)))

  (testing "timestamp query is parsed correctly"
    (is (= (p/parse-search (:search-text timestamp-search))
           timestamp-search)))

  (testing "linked query is parsed correctly"
    (is (= (p/parse-search (:search-text linked-search))
           linked-search)))

  (testing "country query is parsed correctly"
    (is (= country-search
           (p/parse-search (:search-text country-search)))))

  (testing "id query is parsed correctly"
    (is (= (p/parse-search (:search-text id-search))
           id-search))))


(def tags #{"#task" "#goal" "#autocomplete" "#autosuggestion" "#Clojure"
            "#ClojureScript"})
(def mentions #{"@JohnDoe" "@myself" "@me"})

(deftest autocomplete-tags-test
  (testing
    "empty string before cursor returns zero filtered tags"
    (is (= (p/autocomplete-tags "" "(?!^) ?#" tags)
           ["" '()])))

  (testing
    "Hashtag at end of string parsed correctly"
    (is (= (p/autocomplete-tags "some #task" "(?!^) ?#" tags)
           ["#task" '("#task")])))

  (testing
    "empty tags returns empty filtered tags list"
    (is (= (p/autocomplete-tags "some #task" "(?!^) ?#" #{}) ["#task" '()])))

  (testing
    "partial tag correctly matched with multiple matches"
    (is (= (p/autocomplete-tags "some #auto" "(?!^) ?#" tags)
           ["#auto" '("#autocomplete" "#autosuggestion")])))

  (testing
    "not case sensitive"
    (is (= (p/autocomplete-tags "some #cloju" "(?!^) ?#" tags)
           ["#cloju" '("#Clojure" "#ClojureScript")])))

  (testing
    "also working with mentions"
    (is (= (p/autocomplete-tags "@m" "@" mentions)
           ["@m" '("@me" "@myself")]))))

(def codeblock-ignore-str
  "some #detected `#not-detected #not-detected2` some \n```\ncode block @not-detected blah\n```\n some text @detected \n```\n@not-detected #not-detected blah\n```")

(deftest codeblocks-ignored
  (testing "A codeblock that contains tags will not have the tags returned"
    (is (= (p/parse-entry codeblock-ignore-str)
           {:md       codeblock-ignore-str
            :tags     #{"#detected"}
            :mentions #{"@detected"}}))))