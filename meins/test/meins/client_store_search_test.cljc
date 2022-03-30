(ns meins.client-store-search-test
  "Here, we test the search-related handler functions of the client side store
   component."
  (:require #?(:clj  [clojure.test :refer [deftest is testing]]
               :cljs [cljs.test :refer [deftest is testing]])
            [meins.client-store-test :as st]
            [meins.electron.renderer.client-store :as cs]
            [meins.electron.renderer.client-store.search :as search]))

(deftest update-query-test
  "Test that new query is updated properly in store component state"
  (with-redefs [search/query-cfg (atom {})]
    (let [current-state @(:state (cs/state-fn (fn [_put-fn])))
          handler-res (search/update-query-fn {:current-state current-state
                                               :put-fn        (fn [_])
                                               :msg-payload   st/empty-query})
          new-state (:new-state handler-res)
          new-state2 (:new-state (search/update-query-fn
                                   {:current-state new-state
                                    :put-fn        (fn [_])
                                    :msg-payload   st/open-tasks-query}))]
      (testing
        "query is set locally"
        (is (= st/empty-query (-> new-state :query-cfg :queries :query-1))))
      (testing
        "active entry not set"
        (is (not (:active new-state))))
      (testing
        "query is updated"
        (is (= st/open-tasks-query
               (-> new-state2 :query-cfg :queries :query-1))))
      (testing
        "active entry not set after updating query"
        (is (not (:active new-state2)))))))

(deftest show-more-test
  "Ensure that query is properly updated when more results are desired."
  (with-redefs [search/query-cfg (atom {})]
    (let [current-state @(:state (cs/state-fn (fn [_put-fn])))
          new-state (:new-state (search/update-query-fn
                                  {:current-state current-state
                                   :put-fn        (fn [_])
                                   :msg-payload   st/open-tasks-query}))
          {:keys [send-to-self]} (search/show-more
                                   {:current-state new-state
                                    :put-fn        (fn [_])
                                    :msg-payload   {:query-id :query-1}})
          updated-query (second send-to-self)
          expected-query (assoc-in (update-in st/open-tasks-query [:n] + 25) [:incremental] true)]
      (testing
        "send properly updated query, with increased number of results"
        (is (= updated-query
               expected-query))))))

(deftest find-existing-test
  "Tests finding existing queries in tab."
  (let [query-cfg {:queries    {:0f94cca4-160d-4220-8071-b794856b8f9c {:mentions    #{}
                                                                       :tags        #{"#briefing"}
                                                                       :date_string nil
                                                                       :n           20
                                                                       :query-id    :0f94cca4-160d-4220-8071-b794856b8f9c
                                                                       :opts        #{}
                                                                       :ft-search   nil
                                                                       :timestamp   nil
                                                                       :not-tags    #{}
                                                                       :search-text "#briefing "
                                                                       :sort-asc    nil}
                                :a760ca9a-7171-411b-9c55-7f5c66c7e3c3 {:mentions    #{}
                                                                       :tags        #{}
                                                                       :date_string nil
                                                                       :n           20
                                                                       :query-id    :a760ca9a-7171-411b-9c55-7f5c66c7e3c3
                                                                       :opts        #{}
                                                                       :ft-search   nil
                                                                       :timestamp   "1487900192603"
                                                                       :not-tags    #{}
                                                                       :search-text "1487900192603"
                                                                       :sort-asc    nil}
                                :e77973b3-59da-4f6f-ad0b-82d24ed1d82d {:mentions    #{}
                                                                       :tags        #{}
                                                                       :date_string nil
                                                                       :n           20
                                                                       :query-id    :e77973b3-59da-4f6f-ad0b-82d24ed1d82d
                                                                       :opts        #{}
                                                                       :ft-search   nil
                                                                       :timestamp   "1488339624152"
                                                                       :not-tags    #{}
                                                                       :search-text "1488339624152"
                                                                       :sort-asc    nil}
                                :56439d98-3f98-412a-a213-82137a1f8247 {:mentions    #{}
                                                                       :tags        #{}
                                                                       :date_string nil
                                                                       :n           20
                                                                       :query-id    :56439d98-3f98-412a-a213-82137a1f8247
                                                                       :opts        #{}
                                                                       :ft-search   nil
                                                                       :timestamp   "1488339708600"
                                                                       :not-tags    #{}
                                                                       :search-text "1488339708600"
                                                                       :sort-asc    nil}}
                   :tab-groups {:left  {:active :0f94cca4-160d-4220-8071-b794856b8f9c
                                        :all    #{:0f94cca4-160d-4220-8071-b794856b8f9c}}
                                :right {:active :a760ca9a-7171-411b-9c55-7f5c66c7e3c3
                                        :all    #{:a760ca9a-7171-411b-9c55-7f5c66c7e3c3
                                                  :e77973b3-59da-4f6f-ad0b-82d24ed1d82d
                                                  :56439d98-3f98-412a-a213-82137a1f8247}}}}]
    (testing "Finds existing query"
      (is (= {:date_string nil
              :ft-search   nil
              :mentions    #{}
              :n           20
              :not-tags    #{}
              :opts        #{}
              :query-id    :a760ca9a-7171-411b-9c55-7f5c66c7e3c3
              :search-text "1487900192603"
              :sort-asc    nil
              :tags        #{}
              :timestamp   "1487900192603"}
             (search/find-existing query-cfg :right {:search-text "1487900192603"}))))
    (testing "Returns nil for non-existing query"
      (is (= nil
             (search/find-existing query-cfg :right {:search-text "#task"}))))))
