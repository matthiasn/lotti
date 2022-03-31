(ns meins.electron.renderer.ui.preferences.albums
  (:require ["moment" :as moment]
            [clojure.string :as s]
            [meins.electron.renderer.graphql :as gql]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.journal :as j]
            [meins.electron.renderer.ui.preferences.header :refer [header]]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [meins.common.utils.misc :as m]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [error info]]))

(defn album-gql [pvt search-text]
  (let [queries [[:album
                  {:search-text search-text
                   :n           1000}]]
        query (gql/tabs-query queries false pvt)]
    (emit [:gql/query {:q        query
                       :id       :album
                       :res-hash nil
                       :prio     11}])))

(defn albums-gql [pvt search-text]
  (let [queries [[:albums
                  {:search-text search-text
                   :n           1000}]]
        query (gql/tabs-query queries false pvt)]
    (emit [:gql/query {:q        query
                       :id       :albums
                       :res-hash nil
                       :prio     11}])))

(defn album-row [_saga _local]
  (let [show-pvt (subscribe [:show-pvt])
        cfg (subscribe [:cfg])]
    (fn album-row-render [entry local]
      (let [ts (:timestamp entry)
            sel (:selected @local)
            line-click (fn [_]
                         (swap! local assoc-in [:selected] ts)
                         (album-gql @show-pvt (str ts)))
            locale (:locale @cfg :en)
            date-str (h/localize-date (moment (or ts)) locale)
            pvt (-> entry :album_cfg :pvt)
            active (-> entry :album_cfg :active)]
        [:tr {:key      ts
              :class    (when (= sel ts) "active")
              :on-click line-click}
         [:td date-str]
         [:td [:strong (-> entry :album_cfg :title)]]
         [:td [:i.fas {:class (if active "fa-toggle-on" "fa-toggle-off")}]]
         [:td [:i.fas {:class (if pvt "fa-toggle-on" "fa-toggle-off")}]]]))))

(defn albums-list [local]
  (let [pvt (subscribe [:show-pvt])
        gql-res2 (subscribe [:gql-res2])
        input-fn (fn [ev]
                   (let [text (m/lower-case (h/target-val ev))]
                     (swap! local assoc-in [:search] text)))
        open-new (fn [x]
                   (let [ts (:timestamp x)]
                     (swap! local assoc-in [:selected] ts)
                     (album-gql @pvt (str ts))))
        add-click (h/new-entry {:perm_tags #{"#album"}
                                :tags      #{"#album"}
                                :album_cfg {:active true}} open-new)]
    (albums-gql true "#album")
    (fn albums-list-render [local]
      (let [search-text (:search @local "")
            search-match #(h/str-contains-lc? (-> % second :album_cfg :title)
                                              (str search-text))
            pvt-filter (fn [x] (if @pvt true (not (get-in x [1 :album_cfg :pvt]))))
            albums (->> @gql-res2
                        :albums
                        :res
                        (filter pvt-filter)
                        (filter search-match)
                        vals)]
        [:div.col.habits.sagas
         [header "Photo Albums" input-fn search-text add-click]
         [:table.sagas-stories
          [:tbody
           [:tr
            [:th "Created"]
            [:th "Album Title"]
            [:th "Active"]
            [:th "Private"]]
           (for [album albums]
             ^{:key (:timestamp album)}
             [album-row album local])]]]))))

(defn albums-tab [tab-group]
  (let [query-cfg (subscribe [:query-cfg])
        query-id (reaction (get-in @query-cfg [:tab-groups tab-group :active]))
        search-text (reaction (get-in @query-cfg [:queries @query-id :search-text]))
        local-cfg (reaction {:query-id    @query-id
                             :search-text @search-text
                             :tab-group   tab-group})]
    (fn tabs-render [_tab-group]
      [:div.tile-tabs
       [j/journal-view @local-cfg]])))

(defn albums [local]
  [:div.habit-cfg-row
   [h/error-boundary
    [albums-list local]]
   (when (:selected @local)
     [h/error-boundary
      [albums-tab :album]])])
