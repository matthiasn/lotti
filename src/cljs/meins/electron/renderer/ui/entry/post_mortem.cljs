(ns meins.electron.renderer.ui.entry.post-mortem
  (:require ["moment" :as moment]
            [clojure.set :as set]
            [clojure.string :as s]
            [meins.electron.renderer.helpers :as h]
            [meins.electron.renderer.ui.entry.cfg.shared :as cs]
            [meins.electron.renderer.ui.questionnaires :as q]
            [meins.electron.renderer.ui.re-frame.db :refer [emit]]
            [meins.electron.renderer.ui.ui-components :as uc]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [taoensso.timbre :refer [debug error info]]))


(defn post-mortem
  [entry edit-mode?]
  (let [options     (subscribe [:options])
        local       (r/atom {:expanded false})
        start-path  [:post_mortem :start]
        end-path    [:post_mortem :end]
        status-path [:post_mortem :status]]
    (fn post-mortem-render [entry edit-mode?]
      (let [ts (:timestamp entry)]
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
                                      [:final "Final"]]}]]]]]]))))
