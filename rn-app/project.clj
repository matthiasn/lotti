(defproject meo "0.1.0-SNAPSHOT"
  :description "FIXME: write description"
  :url "http://example.com/FIXME"
  :license {:name "Eclipse Public License"
            :url  "http://www.eclipse.org/legal/epl-v10.html"}
  :dependencies [[org.clojure/clojure "1.9.0"]
                 [org.clojure/clojurescript "1.9.946"]
                 [reagent "0.8.0-alpha2" :exclusions [cljsjs/react
                                                      cljsjs/react-dom
                                                      cljsjs/react-dom-server
                                                      cljsjs/create-react-class]]
                 [matthiasn/systems-toolbox "0.6.33"]
                 [matthiasn/systems-toolbox-sente "0.6.27"]
                 [cljs-react-navigation "0.1.1"]
                 [org.clojure/data.avl "0.0.17"]
                 [core-async-storage "0.3.1"]
                 [re-frame "0.10.2"]]
  :plugins [[lein-cljsbuild "1.1.7"]
            [lein-figwheel "0.5.14"]]
  :clean-targets ["target/" "index.ios.js" "index.android.js" #_($PLATFORM_CLEAN$)]
  :aliases {"prod-build"     ^{:doc "Recompile code with prod profile."}
                             ["do" "clean"
                              ["with-profile" "prod" "cljsbuild" "once" "ios"]]
            "advanced-build" ^{:doc "Recompile code for production using :advanced compilation."}
                             ["do" "clean"
                              ["with-profile" "advanced" "cljsbuild" "once"]]}
  :profiles {:dev      {:dependencies [[figwheel-sidecar "0.5.14"]
                                       [com.cemerick/piggieback "0.2.2"]]
                        :source-paths ["src" "env/dev"]
                        :cljsbuild    {:builds [{:id           "ios"
                                                 :source-paths ["src/cljc" "src/cljs" "env/dev"]
                                                 :figwheel     true
                                                 :compiler     {:output-to     "target/ios/not-used.js"
                                                                :main          "env.ios.main"
                                                                :output-dir    "target/ios"
                                                                :optimizations :none}}
                                                {:id           "android"
                                                 :source-paths ["src/cljc" "src/cljs" "env/dev"]
                                                 :figwheel     true
                                                 :compiler     {:output-to     "target/android/not-used.js"
                                                                :main          "env.android.main"
                                                                :output-dir    "target/android"
                                                                :optimizations :none}}
                                                #_($DEV_PROFILES$)]}
                        :repl-options {:nrepl-middleware [cemerick.piggieback/wrap-cljs-repl]}}
             :prod     {:cljsbuild {:builds [
                                             {:id           "ios"
                                              :source-paths ["src/cljc" "src/cljs" "env/prod"]
                                              :compiler     {:output-to          "index.ios.js"
                                                             ;:source-map    "index.ios.js.map"
                                                             :main               "env.ios.main"
                                                             :output-dir         "target/ios"
                                                             :static-fns         true
                                                             :optimize-constants true
                                                             :optimizations      :simple
                                                             :closure-defines    {"goog.DEBUG" false}}}
                                             {:id           "android"
                                              :source-paths ["src/cljc" "src/cljs" "env/prod"]
                                              :compiler     {:output-to          "index.android.js"
                                                             :main               "env.android.main"
                                                             :output-dir         "target/android"
                                                             :static-fns         true
                                                             :optimize-constants true
                                                             :optimizations      :simple
                                                             :closure-defines    {"goog.DEBUG" false}}}
                                             #_($PROD_PROFILES$)]}}
             :advanced {:dependencies [[react-native-externs "0.1.0"]]
                        :cljsbuild    {:builds [
                                                {:id           "ios"
                                                 :source-paths ["src/cljc" "src/cljs" "env/prod"]
                                                 :compiler     {:output-to          "index.ios.js"
                                                                :main               "env.ios.main"
                                                                :output-dir         "target/ios"
                                                                :static-fns         true
                                                                :optimize-constants true
                                                                :optimizations      :advanced
                                                                :closure-defines    {"goog.DEBUG" false}}}
                                                {:id           "android"
                                                 :source-paths ["src/cljc" "src/cljs" "env/prod"]
                                                 :compiler     {:output-to          "index.android.js"
                                                                :main               "env.android.main"
                                                                :output-dir         "target/android"
                                                                :static-fns         true
                                                                :optimize-constants true
                                                                :optimizations      :advanced
                                                                :closure-defines    {"goog.DEBUG" false}}}
                                                #_($ADVANCED_PROFILES$)]}}})
