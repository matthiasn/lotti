(ns meo.electron.renderer.ui.entry.quill
  "Adapted from https://github.com/benhowell/reagent-quill/blob/master/quill.cljs"
  (:require [reagent.core :as r]
            [quill :as quill]))

(defn quill-toolbar [id]
  [:div {:id (str "quill-toolbar-" id)}

   [:span {:class "ql-formats"}
    [:select {:class "ql-header"}
     [:option {:value "1"}]
     [:option {:value "2"}]
     [:option {:value "3"}]
     [:option]]]

   #_[:span {:class "ql-formats"}
      [:select {:class "ql-font"}
       [:option]
       [:option {:value "serif"}]
       [:option {:value "monospace"}]]]

   #_[:span {:class "ql-formats"}
      [:select {:class "ql-size"}
       [:option {:value "small"}]
       [:option]
       [:option {:value "large"}]
       [:option {:value "huge"}]]]

   [:span {:class "ql-formats"}
    [:button {:class "ql-bold"}]
    [:button {:class "ql-italic"}]
    [:button {:class "ql-underline"}]
    [:button {:class "ql-strike"}]
    [:button {:class "ql-blockquote"}]]

   #_[:span {:class "ql-formats"}
      [:select {:class "ql-align"}]]

   #_[:span {:class "ql-formats"}
      [:button {:class "ql-script" :value "sub"}]
      [:button {:class "ql-script" :value "super"}]]

   [:span {:class "ql-formats"}
    [:button {:class "ql-indent" :value "-1"}]
    [:button {:class "ql-indent" :value "+1"}]]

   [:span {:class "ql-formats"}
    [:select {:class "ql-color"}]
    [:select {:class "ql-background"}]]

   [:span {:class "ql-formats"}
    [:button {:class "ql-clean"}]]])


(defn editor [{:keys [id content selection on-change-fn]}]
  (let [this (r/atom nil)
        value #(aget @this "container" "firstChild" "innerHTML")
        did-mount
        (fn [component]
          (reset! this
                  (quill.
                    (aget (.-children (r/dom-node component)) 1)
                    #js {:modules     #js {:toolbar (aget (.-children (r/dom-node component)) 0)}
                         :theme       "snow"
                         :placeholder "Compose an epic..."}))

          (.on @this "text-change"
               (fn [delta old-delta source]
                 (on-change-fn source (value))))

          (if (= selection nil)
            (.setSelection @this nil)
            (.setSelection @this (first selection) (second selection) "api")))

        will-rcv-props
        (fn [component next-props]
          (when (or (not= (:content (second next-props)) (value))
                    (not= (:id (r/props component)) (:id (second next-props))))
            (if (= selection nil)
              (.setSelection @this nil)
              (.setSelection @this (first selection) (second selection) "api"))
            (.pasteHTML @this (:content (second next-props)))))

        render (fn []
                 [:div {:id (str "quill-wrapper-" id)}
                  [quill-toolbar id]
                  [:div {:id                      (str "quill-editor-" id)
                         :class                   "quill-editor"
                         :dangerouslySetInnerHTML {:__html content}}]])]
    (r/create-class
      {:component-did-mount          did-mount
       :component-will-receive-props will-rcv-props
       :display-name                 (str "quill-editor-" id)
       :reagent-render               render})))


