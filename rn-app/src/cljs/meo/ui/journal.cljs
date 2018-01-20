(ns meo.ui.journal
  (:require [reagent.core :as r]
            [re-frame.core :refer [reg-sub subscribe]]
            [meo.ui.shared :refer [view text touchable-highlight]]
            [meo.utils.parse :as p]))

(def defaults {:background-color "lightgreen"
               :padding-left     15
               :padding-right    15
               :padding-top      10
               :padding-bottom   10
               :margin-right     10})

(defn render-item [item]
  [touchable-highlight
   {:style    defaults
    :on-press #()
    :key      (:key item)}
   [text {:style {:color       "white"
                  :text-align  "center"
                  :font-weight "bold"}}
    ;(:title item)
    "Fooooooo"]])

(defn journal [local put-fn]
  (let [entries (subscribe [:entries])]
    (fn [local put-fn]
      (when (= (:active-tab @local) :journal)
        [view {:style {:flex             1
                       :max-height       500
                       :background-color "orange"
                       :width            "100%"}}
         [text {:style {:color       "#777"
                        :text-align  "center"
                        :font-weight "bold"}}
          "Journal"
          ;(str (.-FlatList ReactNative))
          ;(str flat-list)
          ]

         #_[:> flat-list2
            {:data       [{:title "Title Text" :key "item1"}
                          {:title "Title Text 2" :key "item2"}]
             :renderItem render-item
             }]

         #_
         [flat-list
          {
           ;:data       []
           :data       (clj->js [(clj->js {:title "Title Text" :key "item1"})
                                 (clj->js {:title "Title Text 2" :key "item2"})])
           :renderItem render-item}]]))))

