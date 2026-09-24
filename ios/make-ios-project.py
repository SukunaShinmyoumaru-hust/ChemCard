#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 ios/ChemCardsiOS.xcodeproj。

SwiftPM 在这台机器上编不出 iOS 包，而装进真机只有 Xcode 工程这一条路；
手写 project.pbxproj 是为了让「改完一条命令重新生成」成立，工程文件本身不需要手工维护。

对象 ID 全部由路径哈希派生，同一份输入永远得到字节一致的输出，
重新生成工程时 diff 里只会出现真正变化的那几个文件。
"""

import hashlib
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))      # <repo>/ios
ROOT = os.path.dirname(HERE)                           # 仓库根
PROJECT_DIR = os.path.join(HERE, "ChemCardsiOS.xcodeproj")

TARGET_NAME = "ChemCards"
PRODUCT_NAME = "ChemCards"
BUNDLE_ID = "cn.chemcards.ios"
DEPLOYMENT_TARGET = "16.0"
TOOLS_VERSION = "14.1"

# macOS 的装配层在 iOS 上整体不要：NSApplication、NSMenu、手搭 .app、离屏渲染截图
EXCLUDED_PREFIX = "Sources/ChemCards/App/"
SOURCE_ROOTS = ("Sources/ChemCards", "Sources/ChemCardsiOS")

# 资源用 folder reference：Xcode 把目录本身按叶子名拷进 bundle，内部层级原样保留，
# 正好落在 AssetLoader 已有的 Bundle.main.resourceURL/<rel> 查找路径上。
# 反过来一个个文件加进去会被拍平到 bundle 根，Data/ 和 Table/ 子目录就丢了。
RESOURCE_FOLDERS = ["Resources/Characters", "Resources/Data", "Resources/Table",
                    "ios/Assets.xcassets"]

SIGNING_XCCONFIG = "signing.xcconfig"
SIGNING_XCCONFIG_TEXT = """// 签名相关只放这一个文件，工程本体里的 DEVELOPMENT_TEAM 故意留空。
// 生成器每次都会重写 project.pbxproj，只有这个文件是"存在就不动"，
// 所以在 Xcode 图形界面里选好的 Team 不会被下一次重新生成抹掉。
//
// 装真机前：Xcode → Settings → Accounts 登录 Apple ID，
// 然后在这里填上你的 Team ID（Xcode 里账号详情页能看到，10 位字母数字），
// 或者直接在 Xcode 的 Signing & Capabilities 里选——下次重新生成工程时会抄回这里。
DEVELOPMENT_TEAM = 
"""


def object_id(*parts):
    """24 位十六进制，和 Xcode 自己生成的 ID 同形，且对同一输入稳定。"""
    return hashlib.md5("/".join(parts).encode("utf-8")).hexdigest().upper()[:24]


def swift_sources():
    found = []
    for root in SOURCE_ROOTS:
        base = os.path.join(ROOT, root)
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames.sort()
            for name in filenames:
                if not name.endswith(".swift"):
                    continue
                rel = os.path.relpath(os.path.join(dirpath, name), ROOT)
                rel = rel.replace(os.sep, "/")
                if rel.startswith(EXCLUDED_PREFIX):
                    continue
                found.append(rel)
    return sorted(found)


def from_source_root(repo_rel):
    """pbxproj 里的 SOURCE_ROOT 是 .xcodeproj 所在目录，也就是 ios/，所以一律回退一层。"""
    return "../" + repo_rel


def quoted(text):
    return '"%s"' % text.replace("\\", "\\\\").replace('"', '\\"')


def render_settings(settings, indent):
    lines = ["%sbuildSettings = {" % indent]
    for key in sorted(settings):
        value = settings[key]
        if isinstance(value, (list, tuple)):
            body = ", ".join(quoted(item) for item in value)
            lines.append("%s\t%s = (%s,);" % (indent, quoted(key), body))
        else:
            lines.append("%s\t%s = %s;" % (indent, quoted(key), quoted(value)))
    lines.append("%s};" % indent)
    return lines


def file_reference(rid, repo_rel, kind):
    return ("\t\t%s /* %s */ = {isa = PBXFileReference; %s; name = %s; path = %s; "
            "sourceTree = SOURCE_ROOT; };" % (rid, os.path.basename(repo_rel.rstrip("/")), kind,
                                              quoted(os.path.basename(repo_rel.rstrip("/"))),
                                              quoted(from_source_root(repo_rel))))


def build_file(bf_id, ref_id, comment, phase):
    return ("\t\t%s /* %s in %s */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };"
            % (bf_id, comment, phase, ref_id, comment))


def group(gid, name, children):
    lines = ["\t\t%s /* %s */ = {isa = PBXGroup;" % (gid, name),
             "\t\t\tchildren = ("]
    for ref_id, label in children:
        lines.append("\t\t\t\t%s /* %s */," % (ref_id, label))
    lines += ["\t\t\t);",
              "\t\t\tname = %s;" % quoted(name),
              "\t\t\tsourceTree = \"<group>\";",
              "\t\t};"]
    return lines


def main():
    sources = swift_sources()
    missing = [folder for folder in RESOURCE_FOLDERS if not os.path.isdir(os.path.join(ROOT, folder))]
    if missing:
        raise SystemExit("资源目录不在： %s" % ", ".join(missing))

    ids = {
        "project": object_id("project"),
        "target": object_id("target", TARGET_NAME),
        "mainGroup": object_id("group", "main"),
        "sourceGroup": object_id("group", "sources"),
        "resourceGroup": object_id("group", "resources"),
        "productGroup": object_id("group", "products"),
        "product": object_id("product", PRODUCT_NAME),
        "sourcesPhase": object_id("phase", "sources"),
        "frameworksPhase": object_id("phase", "frameworks"),
        "resourcesPhase": object_id("phase", "resources"),
        "projectConfigList": object_id("configList", "project"),
        "targetConfigList": object_id("configList", "target"),
        "projectDebug": object_id("config", "project", "Debug"),
        "projectRelease": object_id("config", "project", "Release"),
        "targetDebug": object_id("config", "target", "Debug"),
        "targetRelease": object_id("config", "target", "Release"),
        "xcconfig": object_id("fileref", SIGNING_XCCONFIG),
    }

    source_refs = [(object_id("fileref", path), object_id("buildfile", path), path) for path in sources]
    resource_refs = [(object_id("folderref", folder), object_id("folderbuildfile", folder), folder)
                     for folder in RESOURCE_FOLDERS]

    project_common = {
        # 手写工程里这一项缺省会走旧式 headermap，xcodebuild 每次编译都警告一遍
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "SDKROOT": "iphoneos",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "MTL_FAST_MATH": "YES",
    }
    project_debug = dict(project_common, **{
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_TESTABILITY": "YES",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "ONLY_ACTIVE_ARCH": "YES",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
        "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
    })
    project_release = dict(project_common, **{
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
        "ENABLE_NS_ASSERTIONS": "NO",
        "MTL_ENABLE_DEBUG_INFO": "NO",
        "SWIFT_COMPILATION_MODE": "wholemodule",
        "SWIFT_OPTIMIZATION_LEVEL": "-O",
        "VALIDATE_PRODUCT": "YES",
    })
    target_common = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "GENERATE_INFOPLIST_FILE": "YES",
        # 和生成器并存：这里只补 INFOPLIST_KEY_ 白名单不收的键
        "INFOPLIST_FILE": "Info.plist",
        # 没有 UILaunchScreen 这一项，iOS 会以旧版固定尺寸启动并上下留黑边：
        # 界面照样渲染，但整体看着就是坏的，而且作者自己看不出原因
        "INFOPLIST_KEY_UILaunchScreen_Generation[sdk=iphoneos*]": "YES",
        "INFOPLIST_KEY_UILaunchScreen_Generation[sdk=iphonesimulator*]": "YES",
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation[sdk=iphoneos*]": "YES",
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation[sdk=iphonesimulator*]": "YES",
        # 开文件共享：Documents 就是 AssetLoader 的覆盖目录，换立绘不用重编译
        "INFOPLIST_KEY_UIFileSharingEnabled": "YES",
        "INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace": "YES",
        "INFOPLIST_KEY_UIStatusBarStyle": "UIStatusBarStyleLightContent",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait",
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
        "PRODUCT_NAME": PRODUCT_NAME,
        "SUPPORTS_MACCATALYST": "NO",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": "1",
    }
    target_debug = dict(target_common, **{"ENABLE_PREVIEWS": "YES"})
    target_release = dict(target_common)

    out = []
    out.append("// !$*UTF8*$!")
    out.append("{")
    out.append("\tarchiveVersion = 1;")
    out.append("\tclasses = {")
    out.append("\t};")
    out.append("\tobjectVersion = 54;")
    out.append("\tobjects = {")

    # PBXBuildFile
    out.append("")
    out.append("/* Begin PBXBuildFile section */")
    for _, bf_id, path in source_refs:
        out.append(build_file(bf_id, object_id("fileref", path), os.path.basename(path), "Sources"))
    for _, bf_id, folder in resource_refs:
        out.append(build_file(bf_id, object_id("folderref", folder), os.path.basename(folder), "Resources"))
    out.append("/* End PBXBuildFile section */")

    # PBXFileReference
    out.append("")
    out.append("/* Begin PBXFileReference section */")
    out.append('\t\t%s /* %s.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; '
               'includeInIndex = 0; path = %s; sourceTree = BUILT_PRODUCTS_DIR; };'
               % (ids["product"], PRODUCT_NAME, PRODUCT_NAME + ".app"))
    out.append('\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; '
               'path = %s; sourceTree = "<group>"; };'
               % (ids["xcconfig"], SIGNING_XCCONFIG, quoted(SIGNING_XCCONFIG)))
    for ref_id, _, path in source_refs:
        out.append(file_reference(ref_id, path, "lastKnownFileType = sourcecode.swift"))
    for ref_id, _, folder in resource_refs:
        # .xcassets 要按资产目录登记，actool 才会编译它；当成普通 folder 只会原样拷进 bundle
        kind = ("lastKnownFileType = folder.assetcatalog"
                if folder.endswith(".xcassets") else "lastKnownFileType = folder")
        out.append(file_reference(ref_id, folder, kind))
    out.append("/* End PBXFileReference section */")

    # PBXFrameworksBuildPhase
    out.append("")
    out.append("/* Begin PBXFrameworksBuildPhase section */")
    out.append('\t\t%s /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; '
               'files = (); runOnlyForDeploymentPostprocessing = 0; };' % ids["frameworksPhase"])
    out.append("/* End PBXFrameworksBuildPhase section */")

    # PBXGroup
    out.append("")
    out.append("/* Begin PBXGroup section */")
    out += group(ids["mainGroup"], "ChemCardsiOS",
                 [(ids["sourceGroup"], "Sources"), (ids["resourceGroup"], "Resources"),
                  (ids["productGroup"], "Products"), (ids["xcconfig"], SIGNING_XCCONFIG)])
    out += group(ids["sourceGroup"], "Sources",
                 [(ref_id, os.path.basename(path)) for ref_id, _, path in source_refs])
    out += group(ids["resourceGroup"], "Resources",
                 [(ref_id, os.path.basename(folder)) for ref_id, _, folder in resource_refs])
    out += group(ids["productGroup"], "Products", [(ids["product"], PRODUCT_NAME + ".app")])
    out.append("/* End PBXGroup section */")

    # PBXNativeTarget
    out.append("")
    out.append("/* Begin PBXNativeTarget section */")
    out.append("\t\t%s /* %s */ = {" % (ids["target"], TARGET_NAME))
    out.append("\t\t\tisa = PBXNativeTarget;")
    out.append("\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXNativeTarget \"%s\" */;"
               % (ids["targetConfigList"], TARGET_NAME))
    out.append("\t\t\tbuildPhases = (")
    out.append("\t\t\t\t%s /* Sources */," % ids["sourcesPhase"])
    out.append("\t\t\t\t%s /* Frameworks */," % ids["frameworksPhase"])
    out.append("\t\t\t\t%s /* Resources */," % ids["resourcesPhase"])
    out.append("\t\t\t);")
    out.append("\t\t\tbuildRules = ();")
    out.append("\t\t\tdependencies = ();")
    out.append("\t\t\tname = %s;" % quoted(TARGET_NAME))
    out.append("\t\t\tproductName = %s;" % quoted(PRODUCT_NAME))
    out.append("\t\t\tproductReference = %s /* %s.app */;" % (ids["product"], PRODUCT_NAME))
    out.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    out.append("\t\t};")
    out.append("/* End PBXNativeTarget section */")

    # PBXProject
    out.append("")
    out.append("/* Begin PBXProject section */")
    out.append("\t\t%s /* Project object */ = {" % ids["project"])
    out.append("\t\t\tisa = PBXProject;")
    out.append("\t\t\tattributes = {")
    out.append("\t\t\t\tBuildIndependentTargetsInParallel = YES;")
    out.append("\t\t\t\tLastUpgradeCheck = 1410;")
    out.append("\t\t\t\tTargetAttributes = {")
    out.append("\t\t\t\t\t%s = {CreatedOnToolsVersion = %s;}; " % (ids["target"], TOOLS_VERSION))
    out.append("\t\t\t\t};")
    out.append("\t\t\t};")
    out.append("\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXProject \"ChemCardsiOS\" */;"
               % ids["projectConfigList"])
    out.append("\t\t\tcompatibilityVersion = \"Xcode 12.0\";")
    out.append("\t\t\tdevelopmentRegion = en;")
    out.append("\t\t\thasScannedForEncodings = 0;")
    out.append("\t\t\tknownRegions = (en, Base);")
    out.append("\t\t\tmainGroup = %s;" % ids["mainGroup"])
    out.append("\t\t\tproductRefGroup = %s /* Products */;" % ids["productGroup"])
    out.append("\t\t\tprojectDirPath = \"\";")
    out.append("\t\t\tprojectRoot = \"\";")
    out.append("\t\t\ttargets = (%s /* %s */);" % (ids["target"], TARGET_NAME))
    out.append("\t\t};")
    out.append("/* End PBXProject section */")

    # PBXResourcesBuildPhase
    out.append("")
    out.append("/* Begin PBXResourcesBuildPhase section */")
    out.append("\t\t%s /* Resources */ = {" % ids["resourcesPhase"])
    out.append("\t\t\tisa = PBXResourcesBuildPhase;")
    out.append("\t\t\tbuildActionMask = 2147483647;")
    out.append("\t\t\tfiles = (")
    for _, bf_id, folder in resource_refs:
        out.append("\t\t\t\t%s /* %s in Resources */," % (bf_id, os.path.basename(folder)))
    out.append("\t\t\t);")
    out.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    out.append("\t\t};")
    out.append("/* End PBXResourcesBuildPhase section */")

    # PBXSourcesBuildPhase
    out.append("")
    out.append("/* Begin PBXSourcesBuildPhase section */")
    out.append("\t\t%s /* Sources */ = {" % ids["sourcesPhase"])
    out.append("\t\t\tisa = PBXSourcesBuildPhase;")
    out.append("\t\t\tbuildActionMask = 2147483647;")
    out.append("\t\t\tfiles = (")
    for _, bf_id, path in source_refs:
        out.append("\t\t\t\t%s /* %s in Sources */," % (bf_id, os.path.basename(path)))
    out.append("\t\t\t);")
    out.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    out.append("\t\t};")
    out.append("/* End PBXSourcesBuildPhase section */")

    # XCBuildConfiguration
    out.append("")
    out.append("/* Begin XCBuildConfiguration section */")
    for cid, name, settings in ((ids["projectDebug"], "Debug", project_debug),
                                (ids["projectRelease"], "Release", project_release)):
        out.append("\t\t%s /* %s */ = {" % (cid, name))
        out.append("\t\t\tisa = XCBuildConfiguration;")
        out += render_settings(settings, "\t\t\t")
        out.append("\t\t\tname = %s;" % quoted(name))
        out.append("\t\t};")
    for cid, name, settings in ((ids["targetDebug"], "Debug", target_debug),
                                (ids["targetRelease"], "Release", target_release)):
        out.append("\t\t%s /* %s */ = {" % (cid, name))
        out.append("\t\t\tisa = XCBuildConfiguration;")
        out.append("\t\t\tbaseConfigurationReference = %s /* %s */;" % (ids["xcconfig"], SIGNING_XCCONFIG))
        out += render_settings(settings, "\t\t\t")
        out.append("\t\t\tname = %s;" % quoted(name))
        out.append("\t\t};")
    out.append("/* End XCBuildConfiguration section */")

    # XCConfigurationList
    out.append("")
    out.append("/* Begin XCConfigurationList section */")
    for list_id, owner, debug_id, release_id in (
            (ids["projectConfigList"], "PBXProject \"ChemCardsiOS\"", ids["projectDebug"], ids["projectRelease"]),
            (ids["targetConfigList"], "PBXNativeTarget \"%s\"" % TARGET_NAME, ids["targetDebug"], ids["targetRelease"])):
        out.append("\t\t%s /* Build configuration list for %s */ = {" % (list_id, owner))
        out.append("\t\t\tisa = XCConfigurationList;")
        out.append("\t\t\tbuildConfigurations = (")
        out.append("\t\t\t\t%s /* Debug */," % debug_id)
        out.append("\t\t\t\t%s /* Release */," % release_id)
        out.append("\t\t\t);")
        out.append("\t\t\tdefaultConfigurationIsVisible = 0;")
        out.append("\t\t\tdefaultConfigurationName = Release;")
        out.append("\t\t};")
    out.append("/* End XCConfigurationList section */")

    out.append("\t};")
    out.append("\trootObject = %s /* Project object */;" % ids["project"])
    out.append("}")

    text = "\n".join(out) + "\n"

    os.makedirs(PROJECT_DIR, exist_ok=True)
    target_path = os.path.join(PROJECT_DIR, "project.pbxproj")
    previous = None
    if os.path.isfile(target_path):
        with open(target_path, "r", encoding="utf-8") as handle:
            previous = handle.read()
    if previous != text:
        with open(target_path, "w", encoding="utf-8") as handle:
            handle.write(text)
        print("已生成 %s（%d 个源文件，%d 个资源目录）"
              % (os.path.relpath(target_path, ROOT), len(sources), len(RESOURCE_FOLDERS)))
    else:
        print("工程文件没变化，跳过写入")

    xcconfig = os.path.join(HERE, SIGNING_XCCONFIG)
    if not os.path.isfile(xcconfig):
        with open(xcconfig, "w", encoding="utf-8") as handle:
            handle.write(SIGNING_XCCONFIG_TEXT)
        print("已生成 %s（Team ID 待填）" % os.path.relpath(xcconfig, ROOT))
        return 0

    # Xcode 图形界面里选 Team 是写进 project.pbxproj 的，而这份文件每次重新生成都被整体覆盖；
    # 把选好的 Team 抄回 xcconfig（base configuration，重新生成动不到它），选一次就不会丢
    with open(xcconfig, "r", encoding="utf-8") as handle:
        config_text = handle.read()
    if re.search(r"^DEVELOPMENT_TEAM\s*=\s*\S", config_text, re.M) or not previous:
        return 0
    picked = re.search(r"DEVELOPMENT_TEAM\s*=\s*([A-Z0-9]{10})", previous)
    if not picked:
        return 0
    config_text = re.sub(r"^DEVELOPMENT_TEAM\s*=.*$",
                         "DEVELOPMENT_TEAM = %s" % picked.group(1),
                         config_text, count=1, flags=re.M)
    with open(xcconfig, "w", encoding="utf-8") as handle:
        handle.write(config_text)
    print("已把 Xcode 里选的 Team %s 抄回 %s"
          % (picked.group(1), os.path.relpath(xcconfig, ROOT)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
