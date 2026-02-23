# Rate Limit Monitor Functions

## Usage Check Function
```bash
# Check current usage and model status
function check_rate_limits() {
    local status_output=$(session_status)
    
    # Parse usage percentages from session_status
    # Look for "X% left" (authoritative usage) - NOT "Day X% left" (reset counter)
    # Look for cooldown patterns like "cooldown 45m"
    # Update rate-limit-state.json with current status
    
    # Alert thresholds:
    # - 80%+ → "⚠️ Rate limit warning: 85% used. Consider fallback?"
    # - 95%+ → "🚨 Rate limit critical: 95% used. Immediate fallback recommended."
    # - Cooldown detected → "⏸️ Model in cooldown. Switch to fallback?"
}
```

## Fallback Consultation
```bash
# Present fallback options when needed
function suggest_fallback() {
    echo "Rate limit issue detected. Available fallbacks:"
    echo "1. Sonnet (anthropic/claude-sonnet-4-20250514) - Best reasoning"
    echo "2. GPT4o (openai/gpt-4o) - Fast, capable"  
    echo "3. Mini (openai/gpt-4o-mini) - Lightweight"
    echo ""
    echo "Which would you prefer for temporary use?"
}
```

## Auto-Restoration Check
```bash
# Test if default model is available again
function check_restoration() {
    local current_state=$(read memory/rate-limit-state.json)
    
    if [[ "$fallback_active" == "true" ]]; then
        # Test default model with session_status
        # If cooldown cleared, restore and notify
        session_status --model="openai-codex/gpt-5.3-codex"
        
        if no_cooldown_detected; then
            echo "✅ Cooldown cleared. Restoring to openai-codex/gpt-5.3-codex"
            # Update state file
            # Switch back to default
        fi
    fi
}
```

## Integration Points

### Pre-Task Check
Before complex operations (multi-step workflows, long generations):
1. Quick session_status check
2. If >90% usage, suggest breaking into smaller chunks
3. If cooldown imminent, recommend fallback first

### Heartbeat Integration
Every 3rd heartbeat (~90 min):
1. Full usage analysis
2. Restoration check if in fallback mode
3. Update trend tracking

### Error Recovery
After rate limit errors:
1. Immediate fallback consultation
2. Set restoration timer
3. Update state tracking