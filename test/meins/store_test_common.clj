(ns meins.store-test-common
  (:require [meins.jvm.files :as f]))

(def simple-query
  {:search-text ""
   :tags        #{}
   :not-tags    #{}
   :mentions    #{}
   :date_string nil
   :timestamp   nil
   :n           40
   :query-id    :query-1})

(def no-results-query
  {:search-text "some #not-existing-tag"
   :tags        #{"#not-existing-tag"}
   :not-tags    #{}
   :mentions    #{}
   :date_string nil
   :timestamp   nil
   :n           40})

(def tasks-query
  (merge simple-query
         {:search-text "#task"
          :tags        #{"#task"}}))

(def tasks-done-query
  (merge simple-query
         {:search-text "#task #done"
          :tags        #{"#task" "#done"}}))

(def tasks-not-done-query
  (merge simple-query
         {:search-text "#task ~#done ~#backlog"
          :tags        #{"#task"}
          :not-tags    #{"#done" "#backlog"}}))

(def test-entries
  [{:mentions  #{}
    :tags      #{"#task"}
    :timestamp 1450998000000
    :md        "Some #task"}
   {:mentions  #{}
    :tags      #{"#task"}
    :timestamp 1450998100000
    :md        "Some other #task"}
   {:mentions  #{}
    :tags      #{"#pvt" "#thing"}
    :timestamp 1450998110000
    :md        "Some #pvt #thing"}
   {:mentions  #{}
    :tags      #{"#task" "#done"}
    :timestamp 1450998200000
    :md        "Some other #task #done"}
   {:mentions  #{}
    :tags      #{"#task" "#completed" "#done"}
    :timestamp 1450998300000
    :md        "Yet another completed #task - #done"}
   {:mentions  #{}
    :tags      #{"#comment"}
    :timestamp 1450998300001
    :comment-for 1450998300000
    :md        "Some #comment"}
   {:mentions  #{}
    :tags      #{"#task" "#completed" "#done"}
    :timestamp 1450998400000
    :md        "And yet another completed #task - #done"}])

(def private-tags #{"#pvt" "#nsfw"})

(defn persist-reducer
  "Reducing function for adding entries to component state."
  [acc entry]
  (:new-state (f/geo-entry-persist-fn {:current-state acc
                                       :put-fn (fn [_])
                                       :msg-payload   entry})))
