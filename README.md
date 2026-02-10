# Gracewords (大字有声圣经)

专为长辈设计的大字版有声圣经，集成 Rust 高性能 TTS 引擎。

## 项目结构 (Project Structure)

- **`lib/`**: Flutter 核心代码
    - `features/`: 业务模块 (阅读、设置等)
    - `core/`: 核心服务 (TTS, DI, Storage)
    - `src/rust/`: Flutter Rust Bridge 生成的 Dart 绑定
- **`rust/`**: Rust 后端代码
    - `src/api/`: 暴露给 Flutter 的 API 接口
    - `Cargo.toml`: Rust 依赖配置
- **`server/`**: 离线资源与服务端工具
    - `models/`: TTS 模型文件 (如 Sherpa-ONNX 离线模型)
    - `bible_cht.db`: 繁体中文数据库
    - `pack_server.py`: 资源分发服务器脚本
- **`resources/`**: 源资源 (不打包进 App)
    - `init_db.sql`: 数据库初始化 SQL
    - `bible_initial.db`: 数据库模板
- **`scripts/`**: 数据处理脚本 (Python)
    - 负责圣经数据抓取、音频处理、格式转换等
- **`assets/`**: 应用内嵌资源 (打包进 App)
    - `bible_chs.db`: 简体中文数据库 (核心)
    - `icons/`: 应用图标
    - `data/`: 配置文件

## 开发环境 (Setup)

1. **Flutter**: 确保安装 Flutter SDK (推荐 3.22+)
2. **Rust**: 确保安装 Rust 工具链 (`rustup`, `cargo`)
3. **Flutter Rust Bridge**:
   ```bash
   cargo install flutter_rust_bridge_codegen@^2.0.0
   ```

## 运行 (Run)

- **Debug 模式**:
  ```bash
  ./dev.sh macos
  ```
- **Release 模式**:
  ```bash
  flutter build macos --release
  ```

## 测试 (Test)

- **运行所有测试**:
  ```bash
  flutter test
  ```

