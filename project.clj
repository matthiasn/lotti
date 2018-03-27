(defproject matthiasn/meo "0.0-SNAPSHOT"
  :description "meo - a personal information manager"
  :url "https://github.com/matthiasn/systems-toolbox"
  :license {:name "GNU AFFERO GENERAL PUBLIC LICENSE"
            :url  "https://www.gnu.org/licenses/agpl-3.0.en.html"}
  :dependencies [[org.clojure/clojure "1.9.0"]
                 [org.clojure/tools.logging "0.4.0"]
                 [ch.qos.logback/logback-classic "1.2.3"]
                 [hiccup "1.0.5"]
                 [org.clojure/data.avl "0.0.17"]
                 [org.clojure/test.check "0.10.0-alpha2"]
                 [clj-pid "0.1.2"]
                 [clj-time "0.14.2"]
                 [clj-http "3.8.0"]
                 [enlive "1.1.6"]
                 [buddy/buddy-sign "2.2.0"]
                 [me.raynes/fs "1.4.6"]
                 [markdown-clj "1.0.2"]
                 [cheshire "5.8.0"]
                 [me.raynes/conch "0.8.0"]
                 [com.taoensso/nippy "2.14.0" :exclusions [com.taoensso/encore]]
                 [com.taoensso/timbre "4.10.0" :exclusions [io.aviso/pretty]]
                 [com.drewnoakes/metadata-extractor "2.11.0"]
                 [ubergraph "0.4.0"]
                 [factual/geo "1.2.1"]
                 [camel-snake-kebab "0.4.0"]
                 [matthiasn/systems-toolbox "0.6.34"]
                 [matthiasn/systems-toolbox-sente "0.6.27"]
                 [org.clojure/tools.reader "1.2.2"]
                 [clucy "0.4.0"]
                 [clj.qrgen "0.4.0"]
                 [image-resizer "0.1.10"]
                 [danlentz/clj-uuid "0.1.7"]]

  :source-paths ["src/cljc" "src/clj/"]

  :clean-targets ^{:protect false} ["prod/main"
                                    "prod/renderer"
                                    "prod/geocoder"
                                    "prod/updater"
                                    "target"
                                    "out"
                                    "dev/renderer"]
  :auto-clean false
  :uberjar-name "meo.jar"

  :main meo.jvm.core
  :jvm-opts ["-Xloggc:/tmp/meoDev-gc.log"]

  :profiles {:uberjar      {:aot :all}
             :test-reagent {:dependencies [[cljsjs/react "15.6.1-2"]
                                           [cljsjs/react-dom "15.6.1-2"]
                                           [cljsjs/create-react-class "15.6.0-2"]]}
             :cljs         {:dependencies [[org.clojure/clojurescript "1.10.238"]
                                           [reagent "0.8.0-alpha2"
                                            :exclusions [cljsjs/react cljsjs/react-dom]]
                                           [re-frame "0.10.5"]
                                           [cljsjs/moment "2.17.1-1"]
                                           [matthiasn/systems-toolbox-electron "0.6.22"]
                                           [secretary "1.2.3"]]}
             :inspect      {:dependencies [[matthiasn/systems-toolbox-kafka "0.6.16"]]
                            :source-paths ["src/cljc" "src/clj/" "env/inspect"]
                            :main         meo.inspect.core}}

  :doo {:paths {:karma "./node_modules/karma/bin/karma"}}

  :plugins [[lein-cljsbuild "1.1.7"
             :exclusions [org.apache.commons/commons-compress]]
            [lein-figwheel "0.5.15"]
            [test2junit "1.3.3"]
            [lein-cloverage "1.0.10"]
            [deraen/lein-sass4clj "0.3.1"]
            [lein-shell "0.5.0"]
            [lein-jlink "0.2.0"]
            [lein-ancient "0.6.15"]]

  :jlink-modules ["java.base" "java.sql" "java.desktop" "java.naming" "java.management"]

  ;:global-vars {*assert* false}

  :test2junit-run-ant true

  :sass {:source-paths ["src/scss/"]
         :target-path  "resources/public/css/"}

  :aliases {"cljs-main"         ["with-profile" "cljs" "cljsbuild" "once" "main"]
            "cljs-renderer"     ["with-profile" "cljs" "cljsbuild" "once" "renderer"]
            "cljs-updater"      ["with-profile" "cljs" "cljsbuild" "once" "updater"]

            "cljs-main-dev"     ["with-profile" "cljs" "cljsbuild" "auto" "main"]
            "cljs-renderer-dev" ["with-profile" "cljs" "cljsbuild" "auto" "renderer-dev"]
            "cljs-updater-dev"  ["with-profile" "cljs" "cljsbuild" "auto" "updater"]

            "dist"              ["do"
                                 ["clean"]
                                 ["test"]
                                 ["cljs-main"]
                                 ["cljs-renderer"]
                                 ["cljs-updater"]
                                 ["sass4clj" "once"]
                                 ["jlink" "assemble"]]}

  :cljsbuild {:test-commands {"cljs-test" ["phantomjs" "test/phantom/test.js" "test/phantom/test.html"]}
              :builds        [{:id           "main"
                               :source-paths ["src/cljc" "src/cljs"]
                               :compiler     {:main           meo.electron.main.core
                                              :target         :nodejs
                                              :output-to      "prod/main/main.js"
                                              :output-dir     "out/main"
                                              :language-in    :ecmascript5
                                              :language-out   :ecmascript5
                                              :optimizations  :simple
                                              :parallel-build true}}

                              {:id           "geocoder"
                               :source-paths ["src/cljc" "src/cljs"]
                               :compiler     {:main           meo.electron.geocoder.core
                                              :target         :nodejs
                                              :output-to      "prod/geocoder/geocoder.js"
                                              :output-dir     "out/geocoder"
                                              :optimizations  :simple
                                              :parallel-build true}}

                              {:id           "renderer"
                               :source-paths ["src/cljc" "src/cljs"]
                               :compiler     {:main           meo.electron.renderer.core
                                              :output-to      "prod/renderer/renderer.js"
                                              :target         :nodejs
                                              :output-dir     "out/renderer"
                                              :optimizations  :simple
                                              :parallel-build true}}
                              {:id           "renderer-dev"
                               :source-paths ["src/cljc" "src/cljs"]
                               :compiler     {:main           meo.electron.renderer.core
                                              :output-to      "dev/renderer/renderer.js"
                                              :output-dir     "dev/renderer"
                                              :source-map     true
                                              :target         :nodejs
                                              :optimizations  :none
                                              :parallel-build true}}

                              {:id           "updater"
                               :source-paths ["src/cljs"]
                               :compiler     {:main           meo.electron.update.core
                                              :output-to      "prod/updater/updater.js"
                                              :output-dir     "out/updater"
                                              :target         :nodejs
                                              :optimizations  :simple
                                              :parallel-build true}}

                              {:id           "cljs-test"
                               :source-paths ["src/cljs" "src/cljc" "test"]
                               :compiler     {:output-to     "out/testable.js"
                                              :output-dir    "out/"
                                              :main          meo.jvm.runner
                                              :process-shim  false
                                              :optimizations :whitespace}}]})
