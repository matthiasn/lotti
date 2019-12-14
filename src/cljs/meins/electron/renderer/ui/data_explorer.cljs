  (ns meins.electron.renderer.ui.data-explorer
  "Slightly modified from https://github.com/kamituel/systems-toolbox-chrome"
  (:require [meins.electron.renderer.localstorage :as sa]
            [re-frame.core :refer [subscribe]]
            [reagent.core :as r]
            [taoensso.timbre :refer [debug info]]))

(defn data->hiccup
  "Converts an arbitrary EDN data structure to the HTML where each element (i.e. map, vector,
  sequence, number, string) are wrapped in DOM elements such as DIV's or SPAN's so they are
  easy to style using CSS."
  ([data expanded-path on-expand-fn]
   (data->hiccup data expanded-path on-expand-fn []))
  ([data expanded-path on-expand-fn current-path]
   (let [key-to-expand (first expanded-path)
         handle-coll (fn [v expand-key]
                       (if (or (not (coll? v)) (= key-to-expand expand-key))
                         [:div (data->hiccup v (rest expanded-path) on-expand-fn (conj current-path expand-key))]
                         [:div.collapsed
                          {:on-click (on-expand-fn (conj current-path expand-key))}
                          (data->hiccup (empty v) expanded-path on-expand-fn [])]))]
     (cond
       (map? data)
       [:div.map (for [[k v] data]
                   ^{:key (hash (conj current-path k))}
                   [:div.key-val
                    [:div (data->hiccup k expanded-path on-expand-fn (conj current-path k))]
                    (handle-coll v k)])]

       (vector? data)
       [:div.vector (for [[idx v]
                          (map-indexed (fn [idx v] [idx v]) data)]
                      ^{:key (hash (conj current-path idx))}
                      [:div (handle-coll v idx)])]

       (seq? data)
       [:div.seq (for [[idx v] (map-indexed (fn [idx v] [idx v]) data)]
                   ^{:key (hash (conj current-path idx))}
                   [:div (handle-coll v idx)])]

       (string? data)
       [:span.string data]

       (number? data)
       [:span.number data]

       (keyword? data)
       [:span.keyword (str data)]

       (nil? data)
       [:span.nil "nil"]

       (or (true? data) (false? data))
       [:Boolean.boolean (str data)]

       :else
       (str data)))))

(defn data-explorer [_data]
  (let [local (sa/local-storage (r/atom {}) "data_explorer")
        db (subscribe [:db])
        expand-fn (fn [path]
                    (fn [_]
                      (reset! local path)))]
    (js/setTimeout #(.scrollTo js/window 0 300) 100)
    (fn data-explorer-render [data]
      (aset js/document "body" "style" "overflow" "scroll")
      [:div.edn-tree.light.full
       [:h2 "Client-side State Explorer"]
       (data->hiccup (or data @db) @local expand-fn)])))

(defn data-explorer2 [_data]
  (let [local (r/atom {})
        db (subscribe [:db])
        expand-fn (fn [path]
                    (fn [_]
                      (reset! local path)))]
    (fn data-explorer-render [data]
      [:div.edn-tree.light
       (data->hiccup (or data @db) @local expand-fn)])))
