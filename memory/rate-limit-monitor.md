# Rate Limit Monitor System

## Implementation Status
- **Created:** 2026-02-23 10:13 EST
- **Status:** Active

## System Design

### Monitoring Triggers
1. **Heartbeat checks** (periodic background)
2. **Pre-task checks** (before complex operations)
3. **Post-error analysis** (after rate limit failures)

### Alert Thresholds
- **80% usage warning** → Manual consultation for fallback
- **95% usage critical** → Immediate fallback recommendation
- **Cooldown detected** → Auto-suggest temporary model switch

### Fallback Management
- **Manual selection:** User chooses fallback model when prompted
- **Temporary switch:** Fallback used only during cooldown period
- **Auto-restoration:** Background monitoring to restore default model when cooldown ends

### State Tracking
```json
{
  "default_model": "openai-codex/gpt-5.3-codex",
  "current_model": "openai-codex/gpt-5.3-codex", 
  "fallback_active": false,
  "fallback_model": null,
  "cooldown_end_estimate": null,
  "last_usage_check": null,
  "usage_warnings_sent": []
}
```

## Current Status
- Default model: openai-codex/gpt-5.3-codex
- Current cooldown: ~57m remaining (as of 10:13 EST)
- Next restoration check: 11:10 EST

## Procedures

### Usage Check (session_status)
- Parse usage percentages and cooldown status
- **Key:** "X% left" is authoritative usage metric
- **Ignore:** "Day X% left" is just a reset counter, not quota status  
- Log timestamps for trend analysis
- Generate alerts based on thresholds

### Fallback Consultation
When limits approached:
1. Alert user with current usage stats
2. Present fallback options with capabilities
3. Wait for manual selection
4. Set restoration timer based on cooldown duration

### Auto-Restoration
- Background check every 15-30 minutes during fallback
- Test default model availability
- Restore when cooldown cleared
- Confirm restoration to user