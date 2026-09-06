#!/usr/bin/env python3
"""Regenerate the dependency-free Xcode project from checked-in Swift sources."""
from hashlib import sha1
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "WhoAmI.xcodeproj"
PROJECT.mkdir(exist_ok=True)

def uid(key):
    return sha1(key.encode()).hexdigest()[:24].upper()

def quoted(value):
    return json.dumps(str(value), ensure_ascii=False)

objects = []
def obj(key, content):
    objects.append(f"\t\t{uid(key)} = {{ {content} }};")
    return uid(key)

def refs(items):
    return "(" + ", ".join(uid(item) for item in items) + ");"

source_paths = sorted((ROOT / "WhoAmI").rglob("*.swift"))
test_paths = sorted((ROOT / "WhoAmIUITests").glob("*.swift"))
for source in source_paths + test_paths:
    relative = source.relative_to(ROOT).as_posix()
    obj(relative, f"isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quoted(relative)}; sourceTree = SOURCE_ROOT;")
    obj("build:" + relative, f"isa = PBXBuildFile; fileRef = {uid(relative)};")

asset = "WhoAmI/Resources/Assets.xcassets"
obj(asset, f"isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = {quoted(asset)}; sourceTree = SOURCE_ROOT;")
obj("build:" + asset, f"isa = PBXBuildFile; fileRef = {uid(asset)};")
obj("app-product", 'isa = PBXFileReference; explicitFileType = wrapper.application; path = WhoAmI.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj("test-product", 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = WhoAmIUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
obj("products", f'isa = PBXGroup; children = {refs(["app-product", "test-product"])} name = Products; sourceTree = "<group>";')
obj("source-group", f'isa = PBXGroup; children = {refs([p.relative_to(ROOT).as_posix() for p in source_paths] + [asset])} name = WhoAmI; sourceTree = "<group>";')
obj("test-group", f'isa = PBXGroup; children = {refs([p.relative_to(ROOT).as_posix() for p in test_paths])} name = WhoAmIUITests; sourceTree = "<group>";')
obj("main-group", f'isa = PBXGroup; children = {refs(["source-group", "test-group", "products"])} sourceTree = "<group>";')

for prefix, paths in [("app", source_paths), ("test", test_paths)]:
    obj(prefix + "-sources", "isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = " +
        refs(["build:" + p.relative_to(ROOT).as_posix() for p in paths]) + " runOnlyForDeploymentPostprocessing = 0;")
    obj(prefix + "-frameworks", "isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;")
    obj(prefix + "-resources", "isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = " +
        refs(["build:" + asset] if prefix == "app" else []) + " runOnlyForDeploymentPostprocessing = 0;")

obj("test-proxy", f"isa = PBXContainerItemProxy; containerPortal = {uid('project')}; proxyType = 1; remoteGlobalIDString = {uid('app-target')}; remoteInfo = WhoAmI;")
obj("test-dependency", f"isa = PBXTargetDependency; target = {uid('app-target')}; targetProxy = {uid('test-proxy')};")
obj("app-target", f"isa = PBXNativeTarget; buildConfigurationList = {uid('app-configs')}; buildPhases = {refs(['app-sources', 'app-frameworks', 'app-resources'])} buildRules = (); dependencies = (); name = WhoAmI; productName = WhoAmI; productReference = {uid('app-product')}; productType = \"com.apple.product-type.application\";")
obj("test-target", f"isa = PBXNativeTarget; buildConfigurationList = {uid('test-configs')}; buildPhases = {refs(['test-sources', 'test-frameworks', 'test-resources'])} buildRules = (); dependencies = {refs(['test-dependency'])} name = WhoAmIUITests; productName = WhoAmIUITests; productReference = {uid('test-product')}; productType = \"com.apple.product-type.bundle.ui-testing\";")

common = {
    "SDKROOT": "iphoneos", "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "SWIFT_VERSION": "5.0", "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES", "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "SWIFT_STRICT_CONCURRENCY": "targeted",
}
app_settings = {
    "PRODUCT_BUNDLE_IDENTIFIER": "com.doyoulikelin.whoami", "PRODUCT_NAME": "$(TARGET_NAME)",
    "GENERATE_INFOPLIST_FILE": "YES", "INFOPLIST_KEY_CFBundleDisplayName": "WhoAmI",
    "INFOPLIST_KEY_UILaunchScreen_Generation": "YES", "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations": "UIInterfaceOrientationPortrait",
    "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.lifestyle",
    "TARGETED_DEVICE_FAMILY": "1", "CODE_SIGN_STYLE": "Automatic",
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "CURRENT_PROJECT_VERSION": "1",
    "MARKETING_VERSION": "0.1.0", "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
    "SWIFT_EMIT_LOC_STRINGS": "YES", "ENABLE_PREVIEWS": "YES",
}
test_settings = {
    "PRODUCT_BUNDLE_IDENTIFIER": "com.doyoulikelin.whoami.uitests", "PRODUCT_NAME": "$(TARGET_NAME)",
    "GENERATE_INFOPLIST_FILE": "YES", "TARGETED_DEVICE_FAMILY": "1", "CODE_SIGN_STYLE": "Automatic",
    "TEST_TARGET_NAME": "WhoAmI", "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @loader_path/Frameworks",
}
for group, settings in [("project", common), ("app", app_settings), ("test", test_settings)]:
    for config in ["Debug", "Release"]:
        values = dict(settings)
        if group == "project":
            values.update({"SWIFT_OPTIMIZATION_LEVEL": "-Onone" if config == "Debug" else "-O",
                           "DEBUG_INFORMATION_FORMAT": "dwarf" if config == "Debug" else "dwarf-with-dsym"})
            if config == "Debug":
                values.update({"ENABLE_TESTABILITY": "YES", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG", "ONLY_ACTIVE_ARCH": "YES"})
        fields = " ".join(f"{key} = {quoted(value)};" for key, value in values.items())
        obj(group + config, f"isa = XCBuildConfiguration; buildSettings = {{ {fields} }}; name = {config};")
    obj(group + "-configs", f"isa = XCConfigurationList; buildConfigurations = {refs([group+'Debug', group+'Release'])} defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")

obj("project", f"isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2630; TargetAttributes = {{ {uid('app-target')} = {{ CreatedOnToolsVersion = 26.3; }}; {uid('test-target')} = {{ CreatedOnToolsVersion = 26.3; TestTargetID = {uid('app-target')}; }}; }}; }}; buildConfigurationList = {uid('project-configs')}; compatibilityVersion = \"Xcode 14.0\"; developmentRegion = zh-Hans; hasScannedForEncodings = 0; knownRegions = (en, Base, \"zh-Hans\"); mainGroup = {uid('main-group')}; productRefGroup = {uid('products')}; projectDirPath = \"\"; projectRoot = \"\"; targets = {refs(['app-target', 'test-target'])}")
(PROJECT / "project.pbxproj").write_text("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n" + "\n".join(objects) + f"\n\t}};\n\trootObject = {uid('project')};\n}}\n")
schemes = PROJECT / "xcshareddata" / "xcschemes"
schemes.mkdir(parents=True, exist_ok=True)
def reference(target, name):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(target)}" BuildableName="{name}" BlueprintName="{name.split(".")[0]}" ReferencedContainer="container:WhoAmI.xcodeproj"/>'
app_ref = reference("app-target", "WhoAmI.app")
test_ref = reference("test-target", "WhoAmIUITests.xctest")
(schemes / "WhoAmI.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2630" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
  <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry>
  <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{test_ref}</BuildActionEntry>
 </BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test_ref}</TestableReference></Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print(f"Generated {PROJECT.name}: {len(source_paths)} Swift sources, {len(test_paths)} UI test sources")
