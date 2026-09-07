# 缓水声音来源

- 原作：Swale flowing into a stream，Siddharth Patil（Ksd5 / Sidpatil），2011-02-27。
- 文件页：https://commons.wikimedia.org/wiki/File:Swale.ogg （核实版本 oldid=1228133884，2026-09-07 下载）。
- 原始下载：https://upload.wikimedia.org/wikipedia/commons/8/84/Swale.ogg
- 许可：[CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/)，作者放弃著作权并允许复用与改编。致谢作者为礼貌署名。
- 留存原始文件 `originals/Swale.ogg`，SHA256 `b71def4798508e588229a5f801fefaed9ac51c5dbad224274123c92e6d183fff`。
- `python3 service/media/prepare.py` 通过 ffmpeg 解码原录音的第 3–28 秒，转换为 24 kHz 单声道 PCM，将末尾 1 秒线性交叉淡化至开头 1 秒，再接中段，整体增益 0.5；输出 24 秒 16-bit WAV。
- 输出 `swale-v1.wav` SHA256 `2f1f2c9472d68e2acd51809bfed4174f46aab419cbd36f85194237af40558766`。不同 ffmpeg 解码版本若产生不同量化结果，须人工核实后更新服务和客户端的摘要。

它是通用阅读环境，不声称复原任何诗的现场。已完成真实录音解码、周期交叉淡化和文件校验；尚未进行人耳循环接缝与突发噪声试听，不能以技术处理声称听感验收完成。仅转换后的 WAV 进入服务镜像，原件留在仓库记录来源。
