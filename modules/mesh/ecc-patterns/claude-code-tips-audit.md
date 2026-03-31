# Claude Code Tips and Patterns Audit

This document consolidates findings from an audit of two key repositories: `ykdojo/claude-code-tips` and `hesreallyhim/awesome-claude-code`. The goal is to extract and centralize Claude Code optimization tips, best practices, and real-world examples to improve our own usage of Claude Code.

## 45 Claude Code Optimization Tips

Extracted from `ykdojo/claude-code-tips/README.md`.

### Basics & Workflow

*   **Tip 0: Customize your status line:** Display model, directory, git branch, token usage, and last message for better context awareness.
*   **Tip 1: Learn essential slash commands:** Master `/usage`, `/chrome`, `/mcp`, `/stats`, and `/clear` for efficient session management.
*   **Tip 2: Talk to Claude Code with your voice:** Use local voice transcription for faster communication. Claude is robust to minor transcription errors.
*   **Tip 3: Break down large problems:** Decompose complex tasks into smaller, solvable sub-problems, mirroring traditional software engineering best practices.
*   **Tip 4: Use Git and GitHub CLI like a pro:** Delegate git operations (commit, branch, PR creation) to Claude to streamline your workflow.
*   **Tip 6: Getting output out of your terminal:** Use `/copy`, `pbcopy`, writing to a file, or opening URLs/apps directly to handle Claude's output cleanly.
*   **Tip 7: Set up terminal aliases:** Create short aliases for frequently used commands (`c` for `claude`, `ch` for `claude --chrome`).
*   **Tip 10: Cmd+A and Ctrl+A are your friends:** Quickly provide context by selecting all content from a page or terminal and pasting it into Claude.
*   **Tip 12: Invest in your own workflow:** Spend time customizing your `CLAUDE.md`, learning tools, and refining your personal processes.
*   **Tip 13: Search through your conversation history:** Ask Claude to search your past conversations stored in `~/.claude/projects/`.
*   **Tip 14: Multitasking with terminal tabs:** Use a "cascade" method, opening new tabs for new tasks and sweeping from left (oldest) to right (newest).
*   **Tip 18: Claude Code as a writing assistant:** Use a back-and-forth process, providing context, giving detailed instructions, and refining the output line by line.
*   **Tip 19: Markdown is the s**t:** Use markdown for documents, blog posts, and more, as Claude is highly efficient at generating it.
*   **Tip 20: Use Notion to preserve links when pasting:** Paste content with links into Notion first, then copy from Notion to preserve the markdown formatting for Claude.
*   **Tip 22: The best way to get better at using Claude Code is by using it:** Embrace the "billion token rule" and use the tool extensively to build intuition.
*   **Tip 24: Use `realpath` to get absolute paths:** Provide clear, unambiguous file paths to Claude.
*   **Tip 25: Understanding CLAUDE.md vs Skills vs Slash Commands vs Plugins:** Know the differences to use the right tool for the job.
*   **Tip 30: Keep CLAUDE.md simple and review it periodically:** Start with an empty `CLAUDE.md` and only add instructions you find yourself repeating.
*   **Tip 31: Claude Code as the universal interface:** Use Claude as the first entry point for any task on your computer, from video editing to data analysis.
*   **Tip 32: It's all about choosing the right level of abstraction:** Flexibly move between high-level "vibe coding" and deep, line-by-line analysis as needed.
*   **Tip 38: Navigating and editing your input box:** Use terminal shortcuts like `Ctrl+A`, `Ctrl+E`, `Ctrl+W` for faster prompt editing.
*   **Tip 39: Spend some time planning, but also prototype quickly:** Balance upfront planning with rapid prototyping to validate ideas and guide Claude effectively.
*   **Tip 40: Simplify overcomplicated code:** Actively ask Claude to simplify its output and question its reasoning to avoid overly complex solutions.
*   **Tip 41: Automation of automation:** If you find yourself repeating a task, think about how you can automate it with a script, skill, or by asking Claude.
*   **Tip 42: Share your knowledge and contribute where you can:** Sharing what you learn helps solidify your understanding and brings new insights from the community.
*   **Tip 43: Keep learning!:** Use `/release-notes`, the community subreddit, and follow DevRel members to stay up-to-date.
*   **Tip 45: Quick setup script:** Use the provided script to quickly configure multiple recommendations from the repository.

### Advanced Techniques & Context Management

*   **Tip 5: AI context is like milk; it's best served fresh and condensed!:** Start new conversations for new topics to maintain peak performance.
*   **Tip 8: Proactively compact your context:** Use a `HANDOFF.md` file or plan mode to summarize progress and start fresh without losing context, rather than relying on auto-compaction.
*   **Tip 9: Complete the write-test cycle for autonomous tasks:** Provide Claude with a way to verify its work, for example by using `tmux` to script interactions and check output.
*   **Tip 11: Use Gemini CLI as a fallback for blocked sites:** Create a skill that uses Gemini CLI via `tmux` to fetch content from sites Claude can't access.
*   **Tip 15: Slim down the system prompt:** Patch the CLI bundle to reduce the default system prompt and tool definitions, saving ~10k tokens.
*   **Tip 16: Git worktrees for parallel branch work:** Ask Claude to create and manage git worktrees to work on multiple branches simultaneously without conflict.
*   **Tip 17: Manual exponential backoff for long-running jobs:** Instruct Claude to check the status of jobs with increasing sleep intervals to efficiently monitor progress.
*   **Tip 21: Containers for long-running risky tasks:** Use Docker containers with `--dangerously-skip-permissions` for tasks that are long-running, experimental, or risky.
*   **Tip 23: Clone/fork and half-clone conversations:** Use the `/fork` command or the provided scripts to branch a conversation or discard the older half to save context.
*   **Tip 36: Running bash commands and subagents in the background:** Use `Ctrl+B` to move long-running tasks to the background and let Claude continue with other work.

### Collaboration & Quality

*   **Tip 26: Interactive PR reviews:** Use Claude as an interactive partner for code reviews, going file-by-file and controlling the pace and depth of the review.
*   **Tip 27: Claude Code as a research tool:** Leverage Claude's ability to interact with various tools (`gh`, containers, Gemini CLI, Playwright) to conduct deep research.
*   **Tip 28: Mastering different ways of verifying its output:** Use a combination of generated tests, visual Git clients, draft PRs, and asking Claude to "double check" its own work.
*   **Tip 29: Claude Code as a DevOps engineer:** Delegate investigation of CI/CD failures to Claude, letting it dig through logs and identify root causes.
*   **Tip 33: Audit your approved commands:** Use a tool like `cc-safe` to scan your settings for risky approved commands to prevent accidents.
*   **Tip 34: Write lots of tests (and use TDD):** Have Claude write tests for its own code, and use a Test-Driven Development workflow for more robust results.
*   **Tip 35: Be braver in the unknown; iterative problem solving:** Tackle unfamiliar codebases and problems by iteratively asking questions and experimenting with Claude's guidance.
*   **Tip 37: The era of personalized software is here:** Leverage Claude to quickly build custom tools and solutions tailored to your specific needs.
*   **Tip 44: Install the dx plugin:** Install the `dx` plugin from the repo to get several useful slash commands and skills bundled together.

## Real-World `CLAUDE.md` Examples and Best Practices

Extracted from `hesreallyhim/awesome-claude-code/README.md` and `ykdojo/claude-code-tips/GLOBAL-CLAUDE.md`.

### General `CLAUDE.md` Philosophy

*   **Keep it Simple:** Start with an empty `CLAUDE.md`. Only add instructions when you find yourself repeating them.
*   **Review Periodically:** Project needs and your own workflows evolve. Review your `CLAUDE.md` files to remove outdated instructions and add new, relevant ones.
*   **Global vs. Project:** Use `~/.claude/CLAUDE.md` for global instructions and a project-level `CLAUDE.md` for project-specific context and rules.

### Content of a Good `CLAUDE.md`

A good `CLAUDE.md` file provides context and constraints. Here are some common patterns observed in the wild:

*   **Project Overview:** A brief description of the project's purpose, main technologies, and architecture.
    *   *Example (`metabase/metabase`):* "This is a large monorepo for Metabase, a business intelligence tool. The backend is primarily Clojure... The frontend is a React/Redux/TypeScript single-page app..."
*   **Development Workflow & Commands:** Key commands for building, testing, and running the project.
    *   *Example (`inkline/inkline`):* "This is a monorepo for Inkline, a Vue.js 3 UI/UX library... To get started, run `pnpm install`... To run the dev server for the docs, run `pnpm dev:docs`."
*   **Coding Standards & Style Guides:** Instructions on code style, formatting, and linting rules to enforce.
    *   *Example (`spylang/spy`):* "The code is formatted using `black` and `isort`. Please run `poe format` to format your code. The code is statically checked using `mypy`. Please run `poe lint` to check for errors."
*   **Architectural Principles:** High-level guidelines on how code should be structured.
    *   *Example (`langchain-ai/langgraphjs`):* "This is a monorepo containing the source code for LangGraphJS. It is a layered library..."
*   **Testing Philosophy:** Instructions on how to write tests, what kind of tests to write, and how to run them.
    *   *Example (`KarpelesLab/tpl`):* "We use table-driven tests. Please write tests in this style."
*   **Commit & PR Guidelines:** Rules for writing commit messages and creating pull requests.
    *   *Example (`giselles-ai/giselle`):* "Use Conventional Commits for commit messages... Branch names should be in the format `type/scope/description`."

### `GLOBAL-CLAUDE.md` Best Practices

From `ykdojo/claude-code-tips/GLOBAL-CLAUDE.md`.

*   **Define Your Persona:** Specify your name, GitHub handle, and the current year to ground Claude's responses and research.
*   **Set Behavioral Defaults:**
    *   Instruct Claude on how to handle large, un-prompted pastes (e.g., "just summarize it").
    *   Dictate how complex bash commands should be handled (e.g., break them down or use a script).
    *   Enforce `cd` instead of `git -C` for consistency.
    *   Keep `stderr` and `stdout` separate.
*   **Establish Safety Protocols:**
    *   **NEVER** use `--dangerously-skip-permissions` on the host machine.
    *   Define a clear process for using containers for risky operations.
    *   Specify how to fetch URLs (e.g., through a container).
    *   Provide a template for using `tmux` for interactive sessions.
*   **Set Interaction Patterns for Specific Tools:**
    *   For browser automation (`Claude for Chrome`), provide explicit instructions to use the accessibility tree (`ref`) instead of coordinates and to avoid screenshots unless requested.

## Missing Patterns and Additional Insights

From synthesizing both repositories.

*   **The Power of Sub-Agents:** Many of the more advanced workflows in `awesome-claude-code` leverage specialized sub-agents. This is a powerful pattern: defining different "personas" or "experts" in `AGENTS.md` that can be called upon for specific tasks (e.g., a "Test-Writer-Agent", a "DevOps-Agent").
*   **Hooks for Automation and Quality:** The `awesome-claude-code` repo highlights the use of hooks for automating quality checks (e.g., running linters, formatters, and tests before a file is written) and for providing notifications. This is a key pattern for building a robust, AI-powered development environment.
*   **Orchestration and Multi-Agent Systems:** Advanced users are building orchestration tools (like `Ruflo` and `Auto-Claude`) on top of Claude Code to manage complex, multi-agent workflows. This points to a future where a primary agent delegates tasks to a swarm of specialized agents.
*   **The Rise of `CLAUDE.md` as "Code":** The `CLAUDE.md` files in `awesome-claude-code` are often highly detailed and structured, acting almost as a form of "configuration-as-code" for the AI's behavior within a project. They go far beyond simple instructions and define a complete operational context.
*   **Community Tooling is Essential:** The ecosystem of tools around Claude Code (status lines, usage monitors, config managers) is crucial for a professional workflow. We should actively explore and adopt these tools.
*   **From "Vibe Coding" to Principled Workflows:** While "vibe coding" is a valid starting point, the most effective patterns (like the "AB Method" or "RIPER Workflow") impose a structured, principled approach to AI-driven development, moving from ad-hoc prompting to a repeatable, spec-driven process.
