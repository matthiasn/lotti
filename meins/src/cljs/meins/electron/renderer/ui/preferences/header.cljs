(ns meins.electron.renderer.ui.preferences.header)

(defn header [title input-fn search-text add-click]
  [:div.header
   [:h2 title]
   [:div.input-line
    [:div.search
     [:i.far.fa-search]
     [:input {:on-change input-fn
              :value     search-text}]]]
   [:div.add {:on-click add-click}
    [:i.fas.fa-plus]]])
