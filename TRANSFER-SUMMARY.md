# What's Included

This deployment packages battle-tested OpenClaw patterns into a ready-to-use setup.

## ✅ Core Systems

### Rate Limit Monitoring
- Automatic tracking of API usage against provider limits
- Alert thresholds at 80% capacity
- Fallback model selection when rate limited
- Auto-restore when cooldowns clear

### Session Startup Flow
- `AGENTS.md` defines automatic context loading each session
- Reads persona, user context, and recent memory on startup
- Consistent behavior across sessions without manual setup

### Heartbeat Monitoring
- Periodic proactive checks (email, calendar, project status)
- Configurable rotation schedule
- Quiet hours respect
- Background work during idle periods

### Memory Organization
- Daily logs (`memory/YYYY-MM-DD.md`) for raw session context
- Long-term memory (`MEMORY.md`) for curated knowledge
- Structured templates for stakeholders, projects, and lessons learned

## ✅ Template Files

| File | Purpose | Customize? |
|------|---------|------------|
| `SOUL.md` | Assistant persona and behavior | Optional |
| `USER.md` | Your context, team, projects | **Required** |
| `IDENTITY.md` | Assistant name and style | **Required** |
| `MEMORY.md` | Stakeholder and project memory | **Required** |
| `TOOLS.md` | Infrastructure and system notes | As needed |
| `HEARTBEAT.md` | Monitoring schedule and hours | Recommended |
| `BOOTSTRAP.md` | Setup checklist (delete when done) | Follow then delete |
| `AGENTS.md` | Session behavior rules | Optional |

## ✅ Communication Framework

- Professional email structure templates
- Stakeholder-appropriate tone adaptation
- Internal vs external communication boundaries
- Meeting prep and follow-up patterns

## ✅ Safety & Boundaries

- Clear rules for what the assistant can do independently vs what requires approval
- External communication guardrails
- Confidentiality protocols
- Data isolation between environments

## 🎯 Design Principles

These patterns were developed through real-world daily use and refined over time:

1. **File-based memory** — everything persists in readable markdown files
2. **Proactive but not annoying** — heartbeats check in periodically without being intrusive
3. **Rate limit awareness** — prevents the most common operational pain point
4. **Security by default** — confidential context stays in main sessions only
5. **Customizable templates** — structured enough to be useful, flexible enough for any environment
