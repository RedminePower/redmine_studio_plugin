# Date Independent

This feature makes parent issue start dates and due dates independent from child issues.

## Overview

In Redmine's "Administration" > "Settings" > "Issue tracking", there is an option to configure how parent issue dates (start date and due date) are calculated.

| Setting | Behavior |
|---------|----------|
| Derived from child issues | Parent issue dates are automatically calculated from child issue dates |
| Independent | Parent issue dates can be set independently of child issues |

When "Derived from child issues" is selected, the earliest start date among child issues becomes the parent's start date, and the latest due date becomes the parent's due date. **This setting applies system-wide, so it cannot be changed per project** - which is a limitation.

This feature resolves this limitation. You can maintain "Derived from child issues" system-wide while making specific projects independent. Additionally, even in independent projects, you can maintain date derivation for issues with certain statuses (e.g., Closed), allowing for fine-grained control.

### Use Cases

**Milestone Issue Management:**
- For projects where release dates are predetermined, you want to fix the parent issue (milestone) due date
- However, child issue work estimates fluctuate, so automatic parent updates cause problems

**Multi-Project Operations:**
- Development projects want dates derived from child issues
- Management projects want dates set manually
- By making only the management project independent with this feature, both can coexist

**Handling Closed Issues:**
- You generally want independence, but closed issues should reflect child issue actuals
- This is achievable by setting "Closed" in "Excluded statuses"

## Administration Screen

You can create, edit, and delete rules from "Start/Due Date Independence" in the administration menu.

## Configuration Options

### Basic Settings

| Item | Description |
|------|-------------|
| Title | Set an easy-to-understand name for administration (required) |
| Enabled | Toggle the rule on/off |
| Target projects | Select projects to make independent (required, multiple selection allowed) |
| Excluded statuses | Specify statuses that should maintain date derivation instead of being independent (multiple selection allowed). If not specified, there are no status-based exceptions |

### Behavior Details

The behavior logic of this feature is as follows:

```
1. If the system setting is not "Derived from child issues"
   → This feature does not operate (follows system setting)

2. If the issue's project is not included in "Target projects"
   → Dates are derived normally

3. If the issue's project is included in "Target projects"
   3-1. "Excluded statuses" is not set
        → Dates are independent (not derived)
   3-2. The issue's status is included in "Excluded statuses"
        → Dates are derived
   3-3. The issue's status is not included in "Excluded statuses"
        → Dates are independent (not derived)
```

### Configuration Examples

**Example 1: Make a specific project completely independent**

| Item | Setting |
|------|---------|
| Title | Management Project Independent |
| Enabled | Checked |
| Target projects | Management Project |
| Excluded statuses | (empty) |

→ Parent issues in the Management Project can have their own dates regardless of child issue dates.

**Example 2: Derive dates only for closed issues**

| Item | Setting |
|------|---------|
| Title | Development Project (derive when closed) |
| Enabled | Checked |
| Target projects | Development Project |
| Excluded statuses | Closed, Rejected |

→ Parent issues in the Development Project are normally independent, but when the status becomes "Closed" or "Rejected", dates are derived from child issues.

## Notes

- This feature only operates when the system setting "Parent issue dates" is set to "Derived from child issues"
- When a rule is disabled, the affected projects will follow the system setting and derive dates accordingly
