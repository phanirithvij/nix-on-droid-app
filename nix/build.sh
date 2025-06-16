#!/usr/bin/env bash

set -x

# generate full dependency report
resolve-gradle-deps

# generate gradle.lock
gen-deps-lock <(
    # missing deps from build report
    #  https://github.com/status-im/status-mobile/blob/674261c7e2808b918e85428073768827ecfc836d/nix/deps/gradle/deps_hack.sh#L29C1-L29C148
    #  https://github.com/googlesamples/android-custom-lint-rules/blob/be672cd747ecf13844918e1afccadb935f856a72/docs/api-guide/example.md.html#L112-L129
    #   version should be gradle version + 23.0.0, as of now 7.4.2 + 23.0.0
    echo -en '
        com.android.tools.lint:lint-gradle:30.4.2
        org.apache.httpcomponents:httpclient:4.5.6
    '
    cat build/reports/dependency-graph-snapshots/dependency-list.txt
)

nix build -L
