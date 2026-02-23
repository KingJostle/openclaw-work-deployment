# HEARTBEAT.md - Work Monitoring

## Rate Limit Monitoring (Every 3rd heartbeat)
- Check session_status for usage patterns
- Alert if >80% of daily/hourly limits
- Monitor for cooldown status changes
- Auto-restore default model when cooldown clears

## Work Context Monitoring (Rotate through these)
- **Email check:** Urgent messages requiring attention
- **Calendar check:** Upcoming meetings (next 2-4 hours)
- **Project status:** Any deliverables due soon
- **Stakeholder follow-ups:** Pending responses or updates

## Rotation Schedule
- **Check 1:** Rate limits + email scan
- **Check 2:** Skip (HEARTBEAT_OK unless urgent)  
- **Check 3:** Rate limits + calendar + project status
- **Repeat cycle**

## Work Hours Respect
- **Business hours:** [Define your work hours]
- **Quiet hours:** [When to avoid non-urgent alerts]
- **Urgency criteria:** [What constitutes urgent vs routine]

## Current cycle: [Update as needed]

---

**CUSTOMIZE:** 
- Set your actual business hours
- Define what constitutes urgent for your role
- Add any work-specific monitoring needs