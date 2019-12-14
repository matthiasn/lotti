(ns meins.electron.renderer.ui.entry.post-mortem
  (:require [meins.electron.renderer.ui.entry.cfg.shared :as cs]
            [meins.electron.renderer.ui.ui-components :as uc]
            [reagent.core :as r]
            [taoensso.timbre :refer [debug error info]]))

(defn post-mortem
  [_entry]
  (let [start-path  [:post_mortem :start]
        end-path    [:post_mortem :end]
        status-path [:post_mortem :status]]
    (fn post-mortem-render [entry]
      [:div.post-mortem
       [:h3 "Post-Mortem Details"]
       [:table
        [:tbody
         [cs/input-table-row entry {:label "Start Date:"
                                    :type  :date
                                    :path  start-path}]
         [cs/input-table-row entry {:label "End Date:"
                                    :type  :date
                                    :path  end-path}]
         [:tr
          [:td [:label "Status:"]]
          [:td
           [uc/select2 {:entry     entry
                        :on-change uc/select-update
                        :path      status-path
                        :xf        keyword
                        :options   [[nil ""]
                                    [:draft "Draft"]
                                    [:proposal "Proposal"]
                                    [:final "Final"]]}]]]]]])))
