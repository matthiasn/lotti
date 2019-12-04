(ns meins.electron.renderer.client-store.search
  (:require #?(:cljs [meins.electron.renderer.localstorage :as sa])
            #?(:clj  [taoensso.timbre :refer [debug info]]
               :cljs [taoensso.timbre :refer [debug info]])
            [matthiasn.systems-toolbox.component :as st]
            [meins.common.utils.misc :as u]
            [meins.common.utils.parse :as p]
            [meins.electron.renderer.graphql :as gql]))

(def initial-query-cfg
  {:queries     {}
   :last-update 0
   :tab-groups  {:left  {:active nil :all #{}}
                 :right {:active nil :all #{}}}})

#?(:clj  (defonce query-cfg (atom initial-query-cfg))
   :cljs (defonce query-cfg (sa/local-storage
                              (atom initial-query-cfg) "meins_query_cfg")))

(defn gql-query [tab-group state incremental put-fn]
  (let [query-cfg (:query-cfg state)
        query-for (fn [k]
                    (let [a (get-in query-cfg [:tab-groups k :active])
                          search-text (get-in query-cfg [:queries a :search-text])
                          story (get-in query-cfg [:queries a :story])
                          flagged (get-in query-cfg [:queries a :flagged])
                          starred (get-in query-cfg [:queries a :starred])
                          from (get-in query-cfg [:queries a :from])
                          to (get-in query-cfg [:queries a :to])
                          n (get-in query-cfg [:queries a :n])]
                      (when (and a search-text)
                        [k {:search-text search-text
                            :story       story
                            :flagged     flagged
                            :starred     starred
                            :from        from
                            :to          to
                            :n           n}])))
        queries (filter identity (map query-for [tab-group]))
        pvt (:show-pvt (:cfg state))
        gql-query (when (seq queries) (gql/tabs-query queries incremental pvt))]
    (put-fn [:gql/query {:q        gql-query
                         :id       tab-group
                         :res-hash nil
                         :prio     1}])))

(defn dashboard-cfg-query [current-state put-fn]
  (let [queries [[:dashboard_cfg
                  {:search-text "#dashboard-cfg"
                   :n           1000}]]
        pvt (:show-pvt (:cfg current-state))
        gql-query (gql/tabs-query queries false pvt)]
    (info gql-query)
    (put-fn [:gql/query {:q        gql-query
                         :id       :dashboard_cfg
                         :res-hash nil
                         :prio     11}])))

(defn update-query-cfg [state put-fn]
  (reset! query-cfg (:query-cfg state))
  (gql-query :left state true put-fn)
  (gql-query :right state true put-fn))

(defn update-query-fn [{:keys [current-state msg-payload put-fn]}]
  (let [query-id (or (:query-id msg-payload) (keyword (str (st/make-uuid))))
        query-path [:query-cfg :queries query-id]
        query-msg (merge msg-payload
                         {:sort-asc (:sort-asc (:cfg current-state))})
        new-state (assoc-in current-state query-path query-msg)
        tab-group (:tab-group msg-payload)]
    (swap! query-cfg assoc-in [:queries query-id] msg-payload)
    (when-not (= (u/cleaned-queries current-state)
                 (u/cleaned-queries new-state))
      (gql-query tab-group new-state true put-fn)
      {:new-state new-state})))

; TODO: linked filter belongs in query-cfg
(defn set-linked-filter [{:keys [current-state msg-payload]}]
  (let [{:keys [search query-id]} msg-payload]
    {:new-state    (assoc-in current-state [:cfg :linked-filter query-id] search)
     :send-to-self [:cfg/save]}))

(defn set-active-query [{:keys [current-state msg-payload put-fn]}]
  (let [{:keys [query-id tab-group]} msg-payload
        path [:query-cfg :tab-groups tab-group :active]
        new-state (-> current-state
                      (assoc-in path query-id)
                      (update-in [:query-cfg :tab-groups tab-group :history]
                                 #(conj (take 20 %1) %2)
                                 query-id))
        new-state (assoc-in new-state [:gql-res2 tab-group :res] (sorted-map-by >))]
    (put-fn [:search/remove {:tab-group tab-group}])
    (when (-> current-state :query-cfg :queries query-id)
      (update-query-cfg new-state put-fn)
      {:new-state new-state})))

(defn find-existing [query-cfg tab-group query]
  (let [all-path [:tab-groups tab-group :all]
        queries (map #(get-in query-cfg [:queries %]) (get-in query-cfg all-path))
        matching (filter #(= (:search-text query) (:search-text %))
                         queries)]
    (first matching)))

(defn add-query [{:keys [current-state msg-payload put-fn]}]
  (let [{:keys [tab-group query]} msg-payload
        query-id (keyword (str (st/make-uuid)))
        active-path [:query-cfg :tab-groups tab-group :active]
        query-path [:query-cfg :queries query-id]
        all-path [:query-cfg :tab-groups tab-group :all]
        new-query (merge {:query-id query-id} (p/parse-search "") query)]
    (if-let [existing (find-existing (:query-cfg current-state) tab-group query)]
      (let [query-id (:query-id existing)
            query-path [:query-cfg :queries query-id]
            new-query (merge existing new-query {:query-id query-id})
            new-state (-> current-state
                          (assoc-in active-path query-id)
                          (assoc-in query-path new-query)
                          (assoc-in [:gql-res2 tab-group :res] (sorted-map-by >)))]
        (put-fn [:search/remove {:tab-group tab-group}])
        (update-query-cfg new-state put-fn)
        {:new-state new-state})
      (let [new-state (-> current-state
                          (assoc-in active-path query-id)
                          (assoc-in query-path new-query)
                          (update-in all-path conj query-id)
                          (update-in [:query-cfg :tab-groups tab-group :history]
                                     #(conj (take 20 %1) %2)
                                     query-id)
                          (assoc-in [:gql-res2 tab-group :res] (sorted-map-by >)))]
        (update-query-cfg new-state put-fn)
        {:new-state new-state}))))

(defn previously-active [state query-id tab-group]
  (let [all-path [:query-cfg :tab-groups tab-group :all]
        active-path [:query-cfg :tab-groups tab-group :active]
        hist-path [:query-cfg :tab-groups tab-group :history]]
    (update-in state active-path
               (fn [active]
                 (if (= active query-id)
                   (let [hist (get-in state hist-path)]
                     (first (filter
                              #(contains? (get-in state all-path) %)
                              hist)))
                   active)))))

(defn query-remove [current-state msg-payload]
  (let [{:keys [query-id tab-group]} msg-payload
        all-path [:query-cfg :tab-groups tab-group :all]
        query-path [:query-cfg :queries]
        new-state (-> current-state
                      (update-in all-path #(disj (set %) query-id))
                      (previously-active query-id tab-group)
                      (update-in query-path dissoc query-id))
        new-state (if query-id
                    (assoc-in new-state [:gql-res2 tab-group :res] (sorted-map-by >))
                    new-state)]
    (info "remove query" tab-group query-id)
    new-state))

(defn update-query [{:keys [current-state msg-payload put-fn]}]
  (let [{:keys [tab-group query]} msg-payload
        query-id (keyword (str (st/make-uuid)))
        active-path [:query-cfg :tab-groups tab-group :active]
        all-path [:query-cfg :tab-groups tab-group :all]]
    (if-let [existing (find-existing (:query-cfg current-state) tab-group query)]
      (let [query-id (:query-id existing)
            new-state (assoc-in current-state active-path query-id)]
        (update-query-cfg new-state put-fn)
        {:new-state new-state})
      (let [new-query (merge {:query-id query-id} (p/parse-search "") query)
            new-state (-> current-state
                          (assoc-in active-path query-id)
                          (assoc-in [:query-cfg :queries query-id] new-query)
                          (update-in all-path conj query-id)
                          (update-in [:query-cfg :tab-groups tab-group :history]
                                     #(conj (take 20 %1) %2)
                                     query-id))]
        (update-query-cfg new-state put-fn)
        {:new-state new-state}))))

(defn remove-query [{:keys [current-state msg-payload put-fn]}]
  (if msg-payload
    (let [new-state (query-remove current-state msg-payload)]
      (update-query-cfg new-state put-fn)
      {:new-state new-state})
    {}))

(defn remove-all [{:keys [current-state msg-payload put-fn]}]
  (let [query-cfg (:query-cfg current-state)
        left (find-existing query-cfg :left msg-payload)
        right (find-existing query-cfg :right msg-payload)
        ml [:search/remove {:tab-group :left
                            :query-id  (:query-id left)}]
        mr [:search/remove {:tab-group :right
                            :query-id  (:query-id right)}]]
    (put-fn ml)
    (put-fn mr)
    {:send-to-self [ml mr]}))

(defn close-all [{:keys [current-state msg-payload put-fn]}]
  (let [{:keys [tab-group]} msg-payload
        all-path [:query-cfg :tab-groups tab-group :all]
        queries-in-grp (get-in current-state all-path)
        query-path [:query-cfg :queries]
        new-state (-> current-state
                      (assoc-in all-path #{})
                      (assoc-in [:query-cfg :tab-groups tab-group :active] nil)
                      (update-in query-path #(apply dissoc % queries-in-grp)))
        new-state (assoc-in new-state [:gql-res2 tab-group :res] (sorted-map-by >))]
    (update-query-cfg new-state put-fn)
    {:new-state new-state}))

(defn set-dragged [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:query-cfg :dragged] msg-payload)]
    (reset! query-cfg (:query-cfg new-state))
    {:new-state new-state}))

(defn move-tab [{:keys [current-state msg-payload put-fn]}]
  (let [dragged (:dragged msg-payload)
        q-id (:query-id dragged)
        from (:tab-group dragged)
        to (:to msg-payload)
        new-state (-> current-state
                      (assoc-in [:query-cfg :tab-groups to :active] q-id)
                      (update-in [:query-cfg :tab-groups to :all] conj q-id)
                      (update-in [:query-cfg :tab-groups from :all] #(disj (set %) q-id))
                      (previously-active q-id from))]
    (update-query-cfg new-state put-fn)
    {:new-state new-state}))

(defn close-tab [{:keys [current-state put-fn]}]
  (debug "close-tab")
  (let [tab-group (get-in current-state [:query-cfg :active-tab-group] :left)
        all-path [:query-cfg :tab-groups tab-group :all]
        active-path [:query-cfg :tab-groups tab-group :active]
        qid (get-in current-state active-path)
        query-path [:query-cfg :queries]
        new-state (-> current-state
                      (update-in all-path #(disj (set %) qid))
                      (previously-active qid tab-group)
                      (update-in query-path dissoc qid))]
    (update-query-cfg new-state put-fn)
    {:new-state new-state}))

(defn next-tab [{:keys [current-state put-fn]}]
  (debug "next-tab")
  (let [tab-group (get-in current-state [:query-cfg :active-tab-group] :left)
        all-path [:query-cfg :tab-groups tab-group :all]
        active-path [:query-cfg :tab-groups tab-group :active]
        qid (get-in current-state active-path)
        queries (get-in current-state all-path)
        next-q (second (drop-while
                         #(not= qid %)
                         (concat queries queries)))]
    (set-active-query {:current-state current-state
                       :msg-payload   {:query-id  next-q
                                       :tab-group tab-group}
                       :put-fn        put-fn})))

(defn active-tab [{:keys [current-state msg-payload]}]
  (debug "active-tab" msg-payload)
  (let [tg (:tab-group msg-payload)]
    {:new-state (assoc-in current-state [:query-cfg :active-tab-group] tg)}))

(defn search-cmd [{:keys [msg-payload] :as m}]
  (let [t (:t msg-payload)]
    (case t
      :close-tab (close-tab m)
      :next-tab (next-tab m)
      :active-tab (active-tab m))))

(defn show-more [{:keys [current-state msg-payload]}]
  (let [query-path [:query-cfg :queries (:query-id msg-payload)]
        merged (merge (get-in current-state query-path) msg-payload)
        new-query (-> merged
                      (update-in [:n] + 25)
                      (assoc-in [:incremental] true))]
    {:send-to-self [:search/update new-query]}))

(defn search-res [{:keys [current-state msg-payload]}]
  (let [{:keys [type data]} msg-payload
        new-state (assoc-in current-state [type] {:ts   (st/now)
                                                  :data data})]
    {:new-state new-state}))

(def search-handler-map
  {:search/update      update-query-fn
   :search/set-active  set-active-query
   :search/add         add-query
   :search/remove      remove-query
   :search/remove-all  remove-all
   :search/close-all   close-all
   :search/set-dragged set-dragged
   :search/move-tab    move-tab
   :search/cmd         search-cmd
   :search/res         search-res
   :show/more          show-more
   :linked-filter/set  set-linked-filter})
