# 一卷山河 · 古典诗词探索系统

> 循诗入境，阅尽山河。

**一卷山河（YiJuanShanHe）** 是一款基于 **C++17、Qt 6 / Qt Quick（QML）与 SQLite** 开发的 Windows 桌面应用。

项目以中国古典诗词为线索，将诗词阅读、诗人生平、地理行旅、意象探索、互动学习和 AI 诗词问答融入统一的交互体验。

采用「**月白**」与「**烟青**」两套水墨主题，融合传统书卷意境与现代桌面应用设计。

## 项目特色

- **沉浸式诗词阅读**：支持原文、注释、译文、赏析、收藏及笔记。
- **诗人时空探索**：通过人生时间线与离线地图探索诗人经历和行旅。
- **诗歌意象星图**：可视化诗词意象的出现频次与共现关系。
- **互动诗词雅集**：提供飞花令、诗词接龙、残卷修复三种玩法。
- **个人诗词手记**：记录阅读足迹、收藏、笔记、学习成绩与偏好设置。
- **AI 诗词助手**：支持自由问答、诗词鉴赏、作品推荐及双诗对比。
- **双主题水墨界面**：月白与烟青两套主题可随时切换。

## 功能模块

| 模块 | 主要功能 |
| --- | --- |
| 山河首页 | 水墨山水动态首页、诗词日历、每日诗词 |
| 诗词典藏 | 诗词检索、分类筛选、原文阅读、译注赏析、收藏笔记 |
| 诗人生平 | 李白、杜甫、苏轼的人物档案、人生时间线、双诗人对照 |
| 诗人行旅 | 离线地理地图、行旅地点、时间轴、路线播放、行旅手札 |
| 意象探索 | 交互式意象星图、词频统计、共现关联、相关诗词 |
| 诗词雅集 | 飞花令、诗词接龙、残卷修复、提示计分与复盘 |
| 个人空间 | 我的收藏、笔记、阅读足迹、学习统计、主题设置 |
| 诗心问墨 | AI 自由问答、诗词鉴赏、作品推荐、双诗对比、历史会话 |

## 技术栈

| 类型 | 技术 |
| --- | --- |
| 开发语言 | C++17 |
| 桌面框架 | Qt 6.5+ |
| 前端界面 | Qt Quick / QML |
| 数据存储 | SQLite、Qt SQL |
| 网络通信 | Qt Network |
| 工程构建 | CMake |
| AI 后端 | Python 3.10+ |
| 运行平台 | Windows |

项目采用 **C++ 业务逻辑 + QML 界面表现** 的分层结构。

C++ 负责数据读取、诗词检索、业务处理及本地持久化，QML 负责界面绘制、交互和动画效果。

## 项目结构

```text
YiJuanShanHe/
├── backend/          # AI 后端服务
├── data/             # 诗人、行旅、意象及地图数据
├── picture/          # 应用美术资源
├── qml/              # QML 页面与组件
│   └── components/
├── src/              # C++ 业务逻辑
├── tests/            # 功能测试
├── shici.txt         # 本地诗词数据
├── main.cpp          # 程序入口
└── CMakeLists.txt     # CMake 构建配置
```

## 安装与运行

### 环境要求

- Windows 10 / 11
- Qt 6.5 或更高版本
- 支持 C++17 的 MinGW 或 MSVC 编译器
- CMake 3.19 或更高版本
- Ninja（使用 Ninja 构建时）

### Qt Creator 运行

1. 克隆项目仓库。
2. 使用 Qt Creator 打开根目录的 `CMakeLists.txt`。
3. 选择 Qt 6.5+ Desktop Kit。
4. 构建并运行 `YiJuanShanHe`。

### 命令行构建

```powershell
git clone https://github.com/wx0602/YiJuanShanHe.git
cd YiJuanShanHe

cmake -S . -B build/home -G Ninja -DCMAKE_PREFIX_PATH="D:/Qt/6.5.3/mingw_64"

cmake --build build/home

.\build\home\YiJuanShanHe.exe
```

请根据本机 Qt 安装位置修改 `CMAKE_PREFIX_PATH`。

## AI 助手配置

「诗心问墨」采用 **Qt 客户端与 Python 后端分离**的架构。

普通用户不需要在桌面界面中填写 API Key。模型服务密钥由独立后端管理。

本地启动后端：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\backend\Start-Local.ps1
```

按提示输入模型服务密钥。

后端默认运行于：

`http://127.0.0.1:8765`

AI 助手支持：

- 自由问答
- 诗词鉴赏
- 诗词推荐
- 双诗对比
- 流式生成与取消
- 对话历史保存
- 跨页面诗词上下文传递

未启动后端时，本地诗词典藏、诗人行旅、意象探索及游戏功能仍然可以使用。

更详细的模型和部署配置请参阅 `backend/README.md`。


## 本地数据管理

项目以 `shici.txt` 为主要诗词数据来源，当前包含 64 首诗词。

其中：

- 首页日历使用前 31 首诗词，对应每月 1—31 日。
- 诗词典藏支持浏览全部 64 首作品。
- 诗人资料保存在 `data/poets.json`。
- 行旅数据保存在 `data/journeys.json`。
- 意象数据保存在 `data/imagery.json`。
- 收藏、笔记、阅读记录及学习成绩通过 SQLite 持久化保存。

## 测试

项目包含诗词典藏、诗词日历、诗人生平、行旅地图、意象探索、互动游戏、个人空间及 AI 助手相关测试。

完成构建后执行：

```powershell
ctest --test-dir build/home --output-on-failure
```

Python 后端测试：

```powershell
python -m unittest discover -s backend -p 'test_*.py' -v
```

## 项目说明

本项目为 C++ / Qt 课程大作业，旨在探索传统文化内容与现代桌面交互技术的结合。

项目综合实践了：

- C++ 面向对象程序设计
- Qt Quick / QML 界面开发
- SQLite 数据库管理
- 交互式地理与图谱可视化
- 桌面应用动画与交互设计
- AI 服务集成

欢迎通过 GitHub Issues 反馈问题或提出改进建议。

---

**一卷山河 · 循诗入境，阅尽山河。**
