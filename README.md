
证书与描述文件： 可从DiFangQiPai SVN 中的iOS_Cer_N_PP中获取，证书需要双击导入到本地电脑中。

不建议使用此工具将开发包重签为上架包用于上架。

工具使用方法：
1. 填写IPA路径（可以将IPA拖入输入框中 或者 点击浏览进行选择 或者手动输入）
2. 填写需要替换的资源路径，需要保持替换与被替换的文件名一致，工具会从IPA中递归查找。支持多个，以','分割
3. (可选)新的描述文件，如果需要替换IPA中的描述文件则填写，否则放空
4. (可选)新的BundleId，需要修改IPA的BundleId则勾选更改并填写，否则放空
5. 选择签名的证书
6. 点击‘开始重签名’，等待签名结束。

如，源IPA为/Users/boyaa/Downloads/test.ipa，重签名后的IPA路径为/Users/boyaa/Downloads/test-resigned.ipa
如果出现失败，请根据弹窗提示检查是否配置错误。

e.g.:
需求 -- 替换/users/Documents/dalian.ipa中 的 /scripts/regionConfig710.lua文件
1. 导入地方棋牌证书:local.p12（已导入过可忽略）
2. 将dalian.ipa拖入签名工具的IPA路径栏
3. 将用于替换的regionConfig710.lua拖入资源路径栏
4. 选择签名的证书 iPhone Distribution: Guangjiu Zhao (7QMD9LVCM8)
5. 点击重签名

常用证书列表：
企业证书 enterprise.p12：iPhone Distribution: Shenzhen Dong Fang Boya Technology Co.Ltd
四川棋牌 sichan.p12： iPhone Distribution: Boyaa Interactive International Limited (94AHJETJ45)
地方棋牌旧地区l ocal.p12：iPhone Distribution: Guangjiu Zhao (7QMD9LVCM8)
楚雄、丽江、玉溪 xiyuan.p12：iPhone Distribution: lian wen (5QVFGL3BHF)
聊城、潍坊、淄博 zhendong.p12：iPhone Distribution: Li Yi (NTQMVSS2LG)

目前只支持对IPA进行签名

常见问题：
1. the codesign_allocate helper tool cannot be found or used
电脑安装了新版本Xcode，请使用sudo xcode-select /path/to/xcode 设置xcode路径