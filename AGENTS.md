# AGENTS.md

## 项目说明

Kayoko 是一个使用 Theos 构建的 Objective-C 越狱插件。本工作区在 RootHide 环境下验证。

## RootHide 构建

在仓库根目录执行：

```sh
make package THEOS=/var/mobile/theos THEOS_PACKAGE_SCHEME=roothide FINALPACKAGE=1 -j2
```

成功后，软件包位于 `packages/`，包架构应为 `iphoneos-arm64e`。

## 架构检查

正式构建后，以下交付 Mach-O 都应同时包含 `arm64` 和 `arm64e`：

```sh
lipo -archs .theos/_/Library/MobileSubstrate/DynamicLibraries/KayokoCore.dylib
lipo -archs .theos/_/Library/MobileSubstrate/DynamicLibraries/KayokoHelper.dylib
lipo -archs .theos/_/Library/PreferenceBundles/KayokoPreferences.bundle/KayokoPreferences
lipo -archs .theos/_/usr/local/libexec/kayoko_updater
lipo -archs .theos/_/usr/local/libexec/kayoko_script
```

## 设备验证

构建成功不代表界面行为已经验证。涉及筛选栏、菜单和状态持久化的改动需要安装软件包后，在历史记录与收藏夹页面分别测试。
