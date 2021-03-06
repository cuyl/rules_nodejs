"Use package-lock.json as input to Bazel fetching packages"

_tarball_target_tmpl = """"Generated by package_lock.bzl"

load("@build_bazel_rules_nodejs//internal/npm_tarballs:npm_tarball.bzl", "npm_tarball")

npm_tarball(
    name = "{name}",
    src = "{src}",
    package_name = "{package_name}",
    deps = {deps},
    visibility = ["//visibility:public"],
)

"""

_alias_tmpl = """
alias(
    name = "%s",
    actual = "%s",
    visibility = ["//visibility:public"],
)

"""

def _escape(package_name):
    "Make a package name into a valid label without slash or at-sign"
    return package_name.replace("/", "-").replace("@", "__")

def _repo_name(package_name, version):
    "Make an external repository name from a package name and a version"
    return "npm_%s-%s" % (_escape(package_name), version)

def _attr(name, value):
    "Produce a key-value attribute indented 8 spaces"
    return " " * 8 + "%s = \"%s\"," % (name, value)

def _list_attr(name, value):
    "Produce a key-value list-typed attribute indented 8 spaces"
    return " " * 8 + "%s = %s," % (name, value)

def _deps_sugar(deps, kind):
    "Produce top-level targets that accumulate all the dependencies or devDependencies"
    return [
        "npm_tarball(",
        "    name = \"%s\"," % kind,
        "    deps = [",
    ] + [" " * 8 + "\"//%s\"," % d for d in deps[kind]] + [
        "    ],",
        "    visibility = [\"//visibility:public\"],",
        ")",
    ]

def _fetch_tarball(repository_ctx, bzl_out, packages):
    "Produce an npm_fetch_tarball target"
    for (name, dep) in packages["dependencies"].items():
        if "resolved" not in dep.keys():
            continue
        target_name = _repo_name(name, dep["version"])
        filename = _escape(name) + "-" + dep["version"] + ".tgz"
        deps = []
        if "dependencies" in dep.keys():
            for (n, d) in dep["dependencies"].items():
                deps.append("@" + _repo_name(n, d["version"]))
        build_file_content = _tarball_target_tmpl.format(
            name = target_name,
            src = filename,
            package_name = name,
            deps = deps,
        )

        bzl_out.extend([
            " " * 4 + "bazel_download(",
            _attr("name", target_name),
            _attr("output", filename),
            _attr("integrity", dep["integrity"]),
            _list_attr("url", [dep["resolved"]]),
            " " * 8 + "build_file_content = \"\"\"" + build_file_content + "\"\"\"",
            " " * 4 + ")",
        ])

def _translate_package_lock(repository_ctx):
    build_content = [
        "# Generated by package_lock.bzl from %s" % str(repository_ctx.attr.package_lock),
        "",
        """load("@build_bazel_rules_nodejs//internal/npm_tarballs:npm_tarball.bzl", "npm_tarball")""",
        "",
    ]
    bzl_content = [
        "\"Generated by package_lock.bzl from %s\"" % str(repository_ctx.attr.package_lock),
        "",
        """load("@build_bazel_rules_nodejs//internal/common:download.bzl", "bazel_download")""",
        "",
        "def npm_repositories():",
        "    \"\"\"Define external repositories to fetch each tarball individually from npm on-demand.",
        "    \"\"\"",
    ]

    # Make a fetch target for each tarball listed in the package_lock
    lock_content = json.decode(repository_ctx.read(repository_ctx.attr.package_lock))
    lock_version = lock_content["lockfileVersion"]
    if lock_version < 2:
        fail("translate_package_lock only works with npm 7 lockfiles (lockfileVersion >= 2), found %s" % lock_version)
    _fetch_tarball(repository_ctx, bzl_content, lock_content)

    # recurse two levels deeper (maybe we need to do more?)
    version_lookup = {}
    for (name, dep) in lock_content["dependencies"].items():
        if "dependencies" in dep.keys():
            _fetch_tarball(repository_ctx, bzl_content, dep)
            for (n2, d2) in dep["dependencies"].items():
                if "dependencies" in d2.keys():
                    _fetch_tarball(repository_ctx, bzl_content, d2)
        if "version" in dep.keys():
            version_lookup[name] = dep["version"]

    # Generate syntax sugar aliases for direct deps
    this_pkg = lock_content["packages"][""]
    direct_deps = []
    if "dependencies" in this_pkg:
        direct_deps.extend(this_pkg["dependencies"])
        build_content.extend(_deps_sugar(this_pkg, "dependencies"))
    if "devDependencies" in this_pkg:
        direct_deps.extend(this_pkg["devDependencies"])
        build_content.extend(_deps_sugar(this_pkg, "devDependencies"))

    repository_ctx.file("index.bzl", "\n".join(bzl_content))
    repository_ctx.file("BUILD.bazel", "\n".join(build_content))
    for dep in direct_deps:
        version = version_lookup[dep]
        if not version.startswith("file:"):
            repository_ctx.file(dep + "/BUILD.bazel", _alias_tmpl % (dep.split("/")[-1], "@" + _repo_name(dep, version)))

# FIXME: also provide an action rule that you can use with `bazel run` to create the npm_deps.bzl
# in cases where you want to then edit it by hand

translate_package_lock = repository_rule(
    doc = """In WORKSPACE, create a new external repo containing a helper index.bzl
        containing a loadable macro that fetches npm packages as needed""",
    implementation = _translate_package_lock,
    attrs = {
        "package_lock": attr.label(mandatory = True),
    },
)
