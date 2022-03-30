(ns meins.electron.renderer.ui.charts.location
  (:require ["emoji-flags" :refer [countryCode]]
            [cljs.pprint :as pp]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as rc]))

(defn loc-table [expanded? per-location label]
  (when (and expanded? (seq per-location))
    [:table.left-padding
     [:tbody
      [:tr
       [:th "Rank"]
       [:th "Flag"]
       [:th label]
       [:th "Days"]]
      (for [[i [loc cnt]] per-location]
        (let [cc (:country loc)
              country (when cc (js->clj (countryCode cc)))
              flag (get country "emoji")]
          ^{:key loc}
          [:tr
           [:td.rank (inc i) "."]
           [:td.flag flag]
           [:td.country (:name loc)]
           [:td.cnt cnt]]))]]))

(defn location-chart []
  (let [local (rc/atom {:last-fetched 0
                        :expanded     true})
        stats (subscribe [:stats])]
    (fn []
      (let [expanded? (:expanded @local)
            per-entity (fn [k]
                         (->> (:locations @stats)
                              k
                              (sort-by second)
                              (filter #(identity (first %)))
                              reverse
                              (map-indexed (fn [idx v] [idx v]))))
            per-country (per-entity :days-per-country)
            per-location (per-entity :days-per-location)
            per-admin-1 (per-entity :days-per-admin-1)
            per-admin-2 (per-entity :days-per-admin-2)
            per-admin-3 (per-entity :days-per-admin-3)
            per-admin-4 (per-entity :days-per-admin-4)]
        [:div.location-stats
         {:class (when expanded? "expanded")}
         [:div.content.white
          [:div.expand {:on-click #(swap! local update-in [:expanded] not)}
           [:span.fa {:class (if expanded? "fa-compress" "fa-expand")}]]
          [:div.row
           [:table
            [:tbody
             (when expanded?
               [:tr
                [:th "Rank"]
                [:th "Flag"]
                [:th "Country"]
                [:th "Days"]])
             (for [[i [cc cnt]] per-country]
               (let [country (js->clj (countryCode cc))
                     flag (get country "emoji")
                     cname (get country "name")]
                 ^{:key cc}
                 [:tr
                  [:td.rank (inc i) "."]
                  [:td.flag flag]
                  [:td.country cname]
                  [:td.cnt cnt]]))]]
           [loc-table expanded? per-location "Location"]
           [loc-table expanded? per-admin-1 "Admin1"]
           [loc-table expanded? per-admin-2 "Admin2"]
           [loc-table expanded? per-admin-3 "Admin3"]
           [loc-table expanded? per-admin-4 "Admin4"]]]]))))
