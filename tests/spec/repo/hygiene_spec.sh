Describe 'repository hygiene'
  ignored() { "$REAL_GIT" -C "$MARKSHARC_ROOT" check-ignore -q --no-index -- "$1"; }

  Describe 'ignore rules'
    Parameters
      AGENTS.md
      CLAUDE.md
      GEMINI.md
      modules/example/CLAUDE.md
      .agents/skills/example/SKILL.md
      .claude/settings.json
      .claude/hooks/example.sh
      .codex/config.toml
      .cursor/rules/example.mdc
      .omp/example
      .cwf-settings.yaml
      .cwf-ai-manifest.json
      .cwf/ai/ext/example.md
      .cwf/phase-runs/phase-1.json
      .vscode/settings.json
      docs/COMMON-WORKFLOW.md
      memory/local/example.md
    End
    It "ignores agent configuration: $1"
      When call ignored "$1"
      The status should be success
    End
  End

  It 'keeps the shared memory index tracked'
    When call ignored memory/MEMORY.md
    The status should be failure
  End

  tracked_agent_config() {
    "$REAL_GIT" -C "$MARKSHARC_ROOT" ls-files |
      grep -E '(^|/)(AGENTS|CLAUDE|GEMINI)\.md$|^\.(agents|claude|codex|cursor|omp|vscode)/|^\.cwf|^docs/COMMON-WORKFLOW\.md$' || :
  }
  It 'tracks no agent configuration'
    When call tracked_agent_config
    The output should equal ''
  End
End
