# Copyright 2020 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
# Cypress rules for Bazel

The Cypress rules run tests under the Cypress e2e testing framework with Bazel.

## Installation

Add `@bazel/cypress` and `cypress` npm packages to your `devDependencies` in `package.json`.

```
npm install --save-dev @bazel/cypress cypress
```
or using yarn
```
yarn add -D @bazel/cypress cypress
```

Then, load and invoke `cypress_repository` within your `WORKSPACE` file.

```python
# Assuming your external repository for node_modules is named @npm

load("@npm//@bazel/cypress:index.bzl", "cypress_repository")

# The name you pass here names the external repository you can load cypress_web_test from
cypress_repository(name = "cypress")
```

### macOS install requirements
On macOS, `cypress_repository` generates an external repository containing files whose names contain spaces. In order to make these files compatible with bazel you will need to add the following flag to your `.bazelrc` file:
```python
# Required for cypress_repository on macOS
build --experimental_inprocess_symlink_creation
```

### windows install requirements
At this point in time, `cypress_repository` is incompatible with bazel sandboxing on Windows. This may change in the future, but for now using cypress on windows requires windows sandboxing be disabled (it is disabled by default)

## Example use of cypress_web_test
This example assumes you've named your external repository for node_modules as `npm` and for cypress as `cypress`
```python
load("@cypress//:index.bzl", "cypress_web_test")
load("@npm//@bazel/typescript:index.bzl", "ts_library")

# You must create a cypress plugin in order to boot a server to serve your application. It can be written as a javascript file or in typescript using ts_library or ts_project.
ts_library(
    name = "plugins_file",
    testonly = True,
    srcs = ["plugin.ts"],
    tsconfig = ":tsconfig.json",
    deps = [
        "@npm//@types/node",
        "@npm//express",
    ],
)

# You can write your cypress tests a javascript files or in typescript using ts_library or ts_project.
ts_library(
    name = "hello_spec",
    testonly = True,
    srcs = ["hello.spec.ts"],
    tsconfig = ":tsconfig.json",
    deps = [
        "@npm//cypress",
    ],
)

cypress_web_test(
    # The name of your test target
    name = "test",
    srcs = [
        # Load javascript test files directly as sources
        "world.spec.js",
        # Load ts_library tests as a target to srcs
        ":hello_spec",
    ],
    # A cypress config file is required
    config_file = "cypress.json",
    # Any runtime dependencies you need to boot your server or run your tests
    data = [],
    # Your cypress plugin used to configure cypress and boot your server
    plugins_file = ":plugins_file",
)
```
"""

load(
    "@build_bazel_rules_nodejs//packages/cypress:internal/cypress_repository.bzl",
    _cypress_repository = "cypress_repository",
)

cypress_repository = _cypress_repository
# DO NOT ADD MORE rules here unless they appear in the generated docsite.
# Run yarn stardoc to re-generate the docsite.
