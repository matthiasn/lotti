(ns meo.runner
  (:require [cljs.test :refer-macros [deftest is testing run-tests]]
            [meo.jvm.client-store-test]
            [meo.electron.renderer.client-store-entry-test]
            [meo.electron.renderer.client-store-search-test]
            [meo.jvm.ui-markdown-test]
            [meo.jvm.ui-pomodoros-test]
            [meo.jvm.parse-test]
            [meo.jvm.misc-utils-test]
            [clojure.string :as s]))

(enable-console-print!)

(defn tests []
  (run-tests 'meo.jvm.client-store-test
             'meo.electron.renderer.client-store-entry-test
             'meo.electron.renderer.client-store-search-test
             'meo.jvm.ui-markdown-test
             'meo.jvm.parse-test
             'meo.jvm.ui-pomodoros-test
             'meo.jvm.misc-utils-test))

(defn ^:export run []
  (tests)
  (let [res (with-out-str (tests))]
    (if (s/includes? res "0 failures, 0 errors") 0 1)))
