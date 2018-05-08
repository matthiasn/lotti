(ns meo.electron.renderer.client-store-search
  (:require #?(:cljs [meo.electron.renderer.localstorage :as sa])
    [meo.electron.renderer.client-store-cfg :as c]
    #?(:clj
    [taoensso.timbre :refer [info debug]]
       :cljs [taoensso.timbre :refer-macros [info debug]])
    [matthiasn.systems-toolbox.component :as st]
    [meo.common.utils.parse :as p]
    [clojure.set :as set]
    [meo.common.utils.misc :as u]))

(def initial-query-cfg
  {:queries     {}
   :last-update 0
   :tab-groups  {:left  {:active nil :all #{}}
                 :right {:active nil :all #{}}}})

#?(:clj  (defonce query-cfg (atom initial-query-cfg))
   :cljs (defonce query-cfg (sa/local-storage
                              (atom initial-query-cfg) "meo_query_cfg")))

(defn update-query-fn
  "Update query in client state, with resetting the active entry in the linked
   entries view."
  [{:keys [current-state msg-payload]}]
  (let [query-id (or (:query-id msg-payload) (keyword (str (st/make-uuid))))
        query-path [:query-cfg :queries query-id]
        query-msg (merge msg-payload
                         {:sort-asc (:sort-asc (:cfg current-state))})
        new-state (assoc-in current-state query-path query-msg)]
    (swap! query-cfg assoc-in [:queries query-id] msg-payload)
    (when-not (= (u/cleaned-queries current-state)
                 (u/cleaned-queries new-state))
      {:new-state new-state
       :emit-msg  [:state/search (u/search-from-cfg new-state)]})))

; TODO: linked filter belongs in query-cfg
(defn set-linked-filter
  "Sets search in linked entries column."
  [{:keys [current-state msg-payload]}]
  (let [{:keys [search query-id]} msg-payload]
    {:new-state    (assoc-in current-state [:cfg :linked-filter query-id] search)
     :send-to-self [:cfg/save]}))

(defn set-active-query
  "Sets active query for specified tab group."
  [{:keys [current-state msg-payload]}]
  (let [{:keys [query-id tab-group]} msg-payload
        path [:query-cfg :tab-groups tab-group :active]
        new-state (-> current-state
                      (assoc-in path query-id)
                      (update-in [:query-cfg :tab-groups tab-group :history]
                                 #(conj (take 20 %1) %2)
                                 query-id))]
    (when (-> current-state :query-cfg :queries query-id)
      (reset! query-cfg (:query-cfg new-state))
      {:new-state new-state})))

(defn find-existing
  "Finds existing query in the same tab group with the same search-text."
  [query-cfg tab-group query]
  (let [all-path [:tab-groups tab-group :all]
        queries (map #(get-in query-cfg [:queries %]) (get-in query-cfg all-path))
        matching (filter #(= (:search-text query) (:search-text %))
                         queries)]
    (first matching)))

(defn add-query
  "Adds query inside tab group specified in msg if none exists already with the
   same search-text. Otherwise opens the existing one."
  [{:keys [current-state msg-payload]}]
  (let [{:keys [tab-group query]} msg-payload
        query-id (keyword (str (st/make-uuid)))
        active-path [:query-cfg :tab-groups tab-group :active]
        all-path [:query-cfg :tab-groups tab-group :all]]
    (if-let [existing (find-existing (:query-cfg current-state) tab-group query)]
      (let [query-id (:query-id existing)
            new-state (assoc-in current-state active-path query-id)]
        (reset! query-cfg (:query-cfg new-state))
        {:new-state new-state})
      (let [new-query (merge {:query-id query-id} (p/parse-search "") query)
            new-state (-> current-state
                          (assoc-in active-path query-id)
                          (assoc-in [:query-cfg :queries query-id] new-query)
                          (update-in all-path conj query-id)
                          (update-in [:query-cfg :tab-groups tab-group :history]
                                     #(conj (take 20 %1) %2)
                                     query-id))]
        (reset! query-cfg (:query-cfg new-state))
        {:new-state new-state}))))

(defn update-query
  "Adds query inside tab group specified in msg if none exists already with the
   same search-text. Otherwise opens the existing one."
  [{:keys [current-state msg-payload]}]
  (let [{:keys [tab-group query]} msg-payload
        query-id (keyword (str (st/make-uuid)))
        active-path [:query-cfg :tab-groups tab-group :active]
        all-path [:query-cfg :tab-groups tab-group :all]]
    (if-let [existing (find-existing (:query-cfg current-state) tab-group query)]
      (let [query-id (:query-id existing)
            new-state (assoc-in current-state active-path query-id)]
        (reset! query-cfg (:query-cfg new-state))
        {:new-state new-state})
      (let [new-query (merge {:query-id query-id} (p/parse-search "") query)
            new-state (-> current-state
                          (assoc-in active-path query-id)
                          (assoc-in [:query-cfg :queries query-id] new-query)
                          (update-in all-path conj query-id)
                          (update-in [:query-cfg :tab-groups tab-group :history]
                                     #(conj (take 20 %1) %2)
                                     query-id))]
        (reset! query-cfg (:query-cfg new-state))
        {:new-state new-state}))))

(defn previously-active
  "Sets active query for the tab group to the previously active query."
  [state query-id tab-group]
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

(defn remove-query
  "Remove query inside tab group specified in msg."
  [{:keys [current-state msg-payload]}]
  (if msg-payload
    (let [{:keys [query-id tab-group]} msg-payload
          all-path [:query-cfg :tab-groups tab-group :all]
          query-path [:query-cfg :queries]
          new-state (-> current-state
                        (update-in all-path #(disj (set %) query-id))
                        (previously-active query-id tab-group)
                        (update-in query-path dissoc query-id)
                        (update-in [:results] dissoc query-id))]
      (reset! query-cfg (:query-cfg new-state))
      {:new-state new-state})
    {}))

(defn remove-all
  "Remove all queries for a given entry inside tab group specified in msg."
  [{:keys [current-state msg-payload]}]
  (let [query-cfg (:query-cfg current-state)
        left (find-existing query-cfg :left msg-payload)
        right (find-existing query-cfg :right msg-payload)]
    {:send-to-self [[:search/remove {:tab-group :left
                                     :query-id  (:query-id left)}]
                    [:search/remove {:tab-group :right
                                     :query-id  (:query-id right)}]]}))

(defn remove-briefing-queries [{:keys [current-state]}]
  (let [briefing-group (-> current-state :query-cfg :tab-groups :briefing)
        off-group (-> current-state :query-cfg :tab-groups :off)
        rm (set/union (set (:all briefing-group)) (set (:all off-group)))
        new-state (-> current-state
                      (update-in [:query-cfg :queries] #(apply dissoc % rm))
                      (assoc-in [:query-cfg :tab-groups :briefing :all] #{})
                      (assoc-in [:query-cfg :tab-groups :off :all] #{})
                      (assoc-in [:query-cfg :tab-groups :off :active] nil))]
    (debug "remove-briefing-queries:" (:query-cfg new-state))
    (reset! query-cfg (:query-cfg new-state))
    {:new-state new-state}))

(defn close-all
  "Remove query inside tab group specified in msg."
  [{:keys [current-state msg-payload]}]
  (let [{:keys [tab-group]} msg-payload
        all-path [:query-cfg :tab-groups tab-group :all]
        queries-in-grp (get-in current-state all-path)
        query-path [:query-cfg :queries]
        new-state (-> current-state
                      (assoc-in all-path #{})
                      (assoc-in [:query-cfg :tab-groups tab-group :active] nil)
                      (update-in query-path #(apply dissoc % queries-in-grp)))]
    (reset! query-cfg (:query-cfg new-state))
    {:new-state new-state}))

(defn set-dragged
  "Set actively dragged tab so it's available when dropped onto another element."
  [{:keys [current-state msg-payload]}]
  (let [new-state (assoc-in current-state [:query-cfg :dragged] msg-payload)]
    (reset! query-cfg (:query-cfg new-state))
    {:new-state new-state}))

(defn move-tab
  "Moves query tab from one tab-group to another."
  [{:keys [current-state msg-payload]}]
  (let [dragged (:dragged msg-payload)
        q-id (:query-id dragged)
        from (:tab-group dragged)
        to (:to msg-payload)
        new-state (-> current-state
                      (assoc-in [:query-cfg :tab-groups to :active] q-id)
                      (update-in [:query-cfg :tab-groups to :all] conj q-id)
                      (update-in [:query-cfg :tab-groups from :all] #(disj (set %) q-id))
                      (previously-active q-id from))]
    (reset! query-cfg (:query-cfg new-state))
    {:new-state new-state}))

(defn show-more
  "Runs previous query but with more results. Also updates the number to show in
   the UI."
  [{:keys [current-state msg-payload]}]
  (let [query-path [:query-cfg :queries (:query-id msg-payload)]
        merged (merge (get-in current-state query-path) msg-payload)
        new-query (update-in merged [:n] + 10)]
    {:send-to-self [:search/update new-query]}))

(defn search-refresh
  "Refreshes client-side state by sending all queries, plus
   the stats and tags."
  [{:keys [current-state msg-meta put-fn]}]
  (let [new-state (-> current-state
                      (assoc-in [:query-cfg :last-update] {:last-update (st/now)
                                                           :meta        msg-meta})
                      (assoc-in [:query-cfg :last-update-meta] msg-meta))]
    (info "search-refresh")
    (when-let [ymd (get-in current-state [:cfg :cal-day])]
      (put-fn [:gql/query {:file "logged-by-day.gql"
                           :id   :logged-by-day
                           :args [ymd]}])
      (put-fn [:gql/query {:file "briefing.gql"
                           :id   :briefing
                           :args [ymd]}]))
    {:new-state new-state
     :emit-msg  [[:state/search (u/search-from-cfg current-state)]
                 [:gql/query {:file "count-stats.gql" :id :count-stats}]
                 [:gql/query {:file "options.gql" :id :options}]]}))

(defn search-res [{:keys [current-state msg-payload put-fn]}]
  (let [{:keys [type data]} msg-payload
        new-state (assoc-in current-state [type] {:ts   (st/now)
                                                  :data data})]
    (doseq [ts data]
      (put-fn [:entry/find {:timestamp ts}]))
    {:new-state new-state}))

(def search-handler-map
  {:search/update           update-query-fn
   :search/set-active       set-active-query
   :search/add              add-query
   :search/remove           remove-query
   :search/remove-all       remove-all
   :search/remove-briefings remove-briefing-queries
   :search/close-all        close-all
   :search/refresh          search-refresh
   :search/set-dragged      set-dragged
   :search/move-tab         move-tab
   :search/res              search-res
   :show/more               show-more
   :linked-filter/set       set-linked-filter})
