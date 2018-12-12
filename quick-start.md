#快速开始

##1.部分仓库目录以及文件介绍

- **AliyunOSSiOSTests**		【测试用例源码】
- **AliyunOSSSDK**			【sdk源代码】
- **Example**	 【OC版项目接入SDK的示例】
- **Images**	【文档中引用的图片】
- **OSSSwiftDemo**	【Swift版项目接入SDK的示例】
- **Scripts**		【搭建获取STS信息的本地服务器python代码】
- **Supporting Files** 【存放支持文件】
- AliyunOSSSDK.xcodeproj	【编译sdk源代码的工程文件】
- AliyunOSSSDK.xcworkspace	【包含了AliyunOSSSDK, OSSSwiftDemo, AliyunOSSiOSTests, Example等工程的工作区文件】
- AliyunOSSiOS.podspec	【用于支持Cocoapods引用的spec文件】
- buildiOSFramework.sh		【编译iOS版本的framework(同时i386,x86_64,armv7,arm64架构),生成好的framework文件存放在仓库根目录下的Products目录下】
- buildOSXFramework.sh		【编译Mac版本的framework,生成好的framework文件存放在仓库根目录下的Products目录下】
- CHANGELOG.txt   【版本变更记录信息】

##使用
**系统环境要求:** 

1.***Mac***系统下安装***Xcode8***以上的版本，以及***Xcode Command Tools***

2.***安装python包管理工具[pip](https://pypi.org/project/pip/)***

```
//bash

sudo easy_install pip

```

3.***安装依赖的python库已经网络模块***

```

// 安装阿里云访问控制的sts授权库
pip install aliyun-python-sdk-sts 

// 安装web模块
pip install web.py

```
如果在安装过程中遇到Permission denied的错误,您需要在执行相关命令前加上***```sudo```***,如***```sudo pip install aliyun-python-sdk-sts```***

1.打开工作区文件
![workspace](https://github.com/aliyun/aliyun-oss-ios-sdk/blob/master/Images/workspace.png)

2.如果您要尝试iOS的OC版本的示例工程进行接口调用,需要修改***Scripts***目录下的sts.py文件
![account_info](https://github.com/aliyun/aliyun-oss-ios-sdk/blob/master/Images/account_info.png)

然后启动本地sts授权服务服务器
***```python Scripts/httpserver.py 本机ip:端口号```***

其中***本机ip***和***端口号***需要您自行设置

3.选择您需要用的scheme
![schemes](https://github.com/aliyun/aliyun-oss-ios-sdk/blob/master/Images/schemes.png)

4.如果您选择的scheme是AliyunOSSSDK-iOS-Example,您需要修改OSSTestMacros.h中的信息
![schemes](https://github.com/aliyun/aliyun-oss-ios-sdk/blob/master/Images/testmacros.png)

如果选择的scheme是OSSSwiftDemo,那么您需要修改的是OSSSwiftGlobalDefines.swift中的信息
![swiftglobalconfig](https://github.com/aliyun/aliyun-oss-ios-sdk/blob/master/Images/swiftglobalconfig.png)

接下来即可体验demo