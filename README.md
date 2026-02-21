# DeepTutor 评估系统

DeepTutor 是一个基于多智能体协作与 RAG 的智能教学辅助系统。本仓库为 **论文评估专用版本**，聚焦于四大核心模块：**出题 (Question Generation)**、**解题 (Question Solving)**、**RAG (检索增强生成)** 和 **Memory (个性化记忆)**。

## 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                      CLI / 评估脚本                          │
├──────────────┬──────────────┬───────────────┬───────────────┤
│  出题模块     │  解题模块     │  记忆系统      │  评估框架      │
│  Question    │  Solve       │  Memory       │  Benchmark    │
│  Generation  │  Agent       │  Personalize  │  + SimuTool   │
├──────────────┴──────────────┴───────────────┴───────────────┤
│                      共享工具层                               │
│         RAG Tool · Web Search · Code Executor               │
├─────────────────────────────────────────────────────────────┤
│                      基础服务层                               │
│    LLM Service · Embedding · RAG Pipeline · Knowledge Base  │
└─────────────────────────────────────────────────────────────┘
```

### 核心模块

- **出题模块** (`src/agents/question/`): 双循环架构（创意循环 + 生成循环），支持基于主题生成和仿题生成两种模式
- **解题模块** (`src/agents/solve/`): Plan → ReAct → Write 三阶段管线，支持多步规划、工具调用和引用标注
- **RAG 服务** (`src/services/rag/`): 统一 RAG 管线，支持 LlamaIndex / LightRAG / RAG-Anything 多种后端
- **记忆系统** (`src/personalization/`): 基于 Trace Forest 的个性化记忆，包含反思、总结、弱点分析三个记忆智能体

## 安装

### 环境要求

- Python >= 3.10
- pip

### 安装步骤

```bash
# 克隆仓库
git clone <repo-url>
cd DeepTutor

# 创建虚拟环境（推荐）
python -m venv venv
source venv/bin/activate  # Linux/macOS
# venv\Scripts\activate   # Windows

# 安装依赖
pip install -r requirements.txt
```

### 配置

复制环境变量模板并填写配置：

```bash
cp .env.example .env
```

必须配置的项目：

| 配置项 | 说明 |
|--------|------|
| `LLM_BINDING` | LLM 提供商（openai, anthropic, deepseek 等） |
| `LLM_MODEL` | 模型名称（如 gpt-4o） |
| `LLM_API_KEY` | API 密钥 |
| `LLM_HOST` | API 端点 |
| `EMBEDDING_BINDING` | 嵌入模型提供商 |
| `EMBEDDING_MODEL` | 嵌入模型名称 |
| `EMBEDDING_API_KEY` | 嵌入模型 API 密钥 |
| `EMBEDDING_HOST` | 嵌入模型端点 |
| `EMBEDDING_DIMENSION` | 向量维度 |

可选配置项包括搜索服务 (`SEARCH_PROVIDER`, `SEARCH_API_KEY`) 等，详见 `.env.example`。

## CLI 使用方式

### 交互式启动器

```bash
python start.py
```

提供 Solver 和 Question Generator 的交互式菜单。

### 解题 CLI

```bash
# 单次求解
python -m src.agents.solve.cli "What is linear convolution?" --kb Calculus

# 详细模式（迭代式答案）
python -m src.agents.solve.cli "What is linear convolution?" --detailed

# 交互模式
python -m src.agents.solve.cli -i --language zh
```

### 出题 CLI

```bash
python src/agents/question/cli.py
```

支持两种模式：
- **Topic 模式**：基于知识点主题生成题目
- **Mimic 模式**：基于试卷 PDF 仿题生成

### 记忆系统

记忆系统在 `start.py` 启动时自动随主进程初始化，无需额外启动。解题和出题过程中的学习事件会自动被 EventBus 捕获，由三个记忆 Agent（反思/总结/弱点分析）并行处理并更新用户记忆文档。

## 评估框架

### 模拟器工具 (benchmark/simulation/)

为学生模拟器提供工作空间隔离的工具接口：

- `solve_question()` — 完整的 Plan → ReAct → Write 解题管线
- `generate_questions()` — 生成选择题（答案对学生隐藏）
- `submit_answers()` — 提交答案并自动判分，触发记忆更新

详细用法参见 `benchmark/simulation/USE.md`。

### Benchmark 框架 (benchmark/)

完整的评估框架，包含：

- **数据生成** (`benchmark/data_generation/`): 从知识库自动生成评估数据（知识范围 → 学生画像 → 知识缺口 → 任务）
- **对话模拟** (`benchmark/simulation/`): LLM 驱动的学生智能体与教师的多轮对话模拟
- **评估打分** (`benchmark/evaluation/`): LLM-as-Judge 在回合级和对话级进行多维度评估

```bash
# 运行评估
python -m benchmark.evaluation.run <transcript_path>
```

## 目录结构

```
DeepTutor/
├── benchmark/                 # 评估框架（数据生成、对话模拟、模拟器工具、评估打分）
├── config/
│   ├── agents.yaml            # 智能体参数（temperature, max_tokens）
│   ├── main.yaml              # 主配置（路径、工具、出题/解题参数）
│   └── memory.yaml            # 记忆系统配置
├── data/
│   ├── knowledge_bases/       # 知识库存储
│   └── user/                  # 用户数据（解题输出、出题批次、记忆文档）
├── start.py                   # CLI 启动器（含记忆系统）
├── src/
│   ├── agents/
│   │   ├── question/          # 出题模块（Idea Agent → Evaluator → Generator → Validator）
│   │   └── solve/             # 解题模块（Planner → Solver → Writer）
│   ├── config/                # 配置常量和默认值
│   ├── core/                  # EventBus 事件总线、错误基类
│   ├── knowledge/             # 知识库管理（创建、文档添加、检索）
│   ├── logging/               # 统一日志系统
│   ├── personalization/       # 记忆系统（Trace Forest、反思/总结/弱点 Agent）
│   ├── services/
│   │   ├── config/            # 配置加载
│   │   ├── embedding/         # 嵌入模型服务
│   │   ├── llm/               # LLM 服务（Factory 模式，支持多提供商）
│   │   ├── prompt/            # Prompt 管理（YAML 模板加载）
│   │   ├── rag/               # RAG 管线（解析 → 分块 → 索引 → 检索）
│   │   ├── search/            # Web 搜索服务（多提供商）
│   │   ├── session/           # 会话管理
│   │   └── setup/             # 系统初始化
│   ├── tools/
│   │   ├── code_executor.py   # Python 代码执行
│   │   ├── rag_tool.py        # RAG 检索工具
│   │   ├── web_search.py      # Web 搜索工具
│   │   ├── multi_kb_rag_tool.py  # 多知识库 RAG
│   │   └── question/          # 出题专用工具（PDF 解析、题目提取、仿题）
│   └── utils/                 # 通用工具
├── tests/                     # 单元测试
├── .env.example               # 环境变量模板
├── config/                    # 配置文件
├── pyproject.toml             # Python 项目配置
└── requirements.txt           # Python 依赖
```

## 配置文件说明

| 文件 | 说明 |
|------|------|
| `config/agents.yaml` | 各智能体模块的 temperature 和 max_tokens 参数 |
| `config/main.yaml` | 系统路径、工具配置、出题/解题参数 |
| `config/memory.yaml` | 记忆系统配置（LLM 模型、自动更新开关、Agent 启用状态） |
| `.env` | 环境变量（LLM/Embedding API 密钥和端点） |

## License

AGPL-3.0
