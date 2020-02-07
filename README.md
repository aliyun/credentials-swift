English | [简体中文](./README-CN.md)

![](https://aliyunsdk-pages.alicdn.com/icons/AlibabaCloud.svg)

## Alibaba Cloud Credentials for Swift(5.1)

[![Cocoapod Version](https://img.shields.io/cocoapods/v/AlibabaCloudCredentials)](https://cocoapods.org/pods/AlibabaCloudCredentials)

## Requirements

- iOS 13.3+ / macOS 10.15+
- Xcode 11.3+
- Swift 5.1

## Installation

### CocoaPods

[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate `AlibabaCloudCredentials` into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
pod 'AlibabaCloudCredentials', '~> 0.1.0'
```

### Carthage

To integrate `AlibabaCloudCredentials` into your Xcode project using [Carthage](https://github.com/Carthage/Carthage), specify it in your `Cartfile`:

```ogdl
github "aliyun/credential-swift" "0.1.0"
```

### Swift Package Manager

To integrate `AlibabaCloudCredentials` into your Xcode project using [Swift Package Manager](https://swift.org/package-manager/) , adding `AlibabaCloudCredentials` to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/aliyun/credential-swift.git", from: "0.1.0")
]
```

In addition, you also need to add `"AlibabaCloudCredentials"` to the `dependencies` of the `target`, as follows:

```swift
.target(
    name: "<your-project-name>",
    dependencies: [
        "AlibabaCloudCredentials",
    ])
```

## Issues
[Opening an Issue](https://github.com/aliyun/credential-swift/issues/new), Issues not conforming to the guidelines may be closed immediately.

## Changelog
Detailed changes for each release are documented in the [release notes](./ChangeLog.md).

## References
* [OpenAPI Explorer](https://api.aliyun.com/)
* [Latest Release](https://github.com/aliyun/credential-swift)

## License
[Apache-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Copyright (c) 2009-present, Alibaba Cloud All rights reserved.
