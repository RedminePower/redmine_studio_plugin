# Wiki Lists

This feature provides macros that display lists of issues or wiki pages in wiki pages or issue descriptions.

## Overview

The following three macros are provided:

| Macro | Description |
|-------|-------------|
| `wiki_list` | Display a list of wiki pages in table format |
| `issue_name_link` | Generate a link from an issue's subject |
| `ref_issues` | Display a list of issues matching specified conditions |

### Use Cases

**wiki_list:**
- Display a list of all wiki pages in a project
- Display child pages with information such as assignee and status
- Extract specific keywords from wiki pages and display them in a table

**issue_name_link:**
- Create links using the subject instead of issue numbers
- Create links to issues in other projects using their subjects

**ref_issues:**
- Embed custom query results in wiki pages
- Dynamically display a list of issues matching specific conditions
- Display issue counts

## wiki_list Macro

Displays a list of wiki pages in table format. You can also extract specific keywords from page content and display them as columns.

### Basic Syntax

```
{{wiki_list([options], [column specifications]...)}}
```

### Options

| Option | Description |
|--------|-------------|
| `-p` | Show only pages from the current project |
| `-p=project_name` | Show only pages from the specified project |
| `-c` | Target only child pages |
| `-w=width` | Specify table width (e.g., `-w=80%`) |

### Column Specifications

| Format | Description |
|--------|-------------|
| `+title` | Page title (with link) |
| `+alias` | Page alias (redirect) |
| `+project` | Project name |
| `keyword:` | Extract text from keyword to end of line |
| `keyword:\terminator` | Extract text from keyword to terminator string |

You can add display names and widths to column specifications:

| Format | Description |
|--------|-------------|
| `keyword\|display_name` | Use display name for column header |
| `keyword\|display_name\|width` | Specify display name and column width |

### Usage Examples

- Display title list of all wiki pages in the current project
  ```
  {{wiki_list(-p, +title)}}
  ```

- Display child page titles with "Page Name" as the header
  ```
  {{wiki_list(-c, +title|Page Name)}}
  ```

- Display page list from current project with text following "Assignee:" from each page
  ```
  {{wiki_list(-p, +title, Assignee:)}}
  ```

- Display three columns (page name, assignee, status) with specified widths (status extracts until newline)
  ```
  {{wiki_list(-p, +title|Page Name|200px, Assignee:|Assignee|150px, Status:\n|Status)}}
  ```

- Display page list from another project with project names
  ```
  {{wiki_list(-p=other_project, +title, +project)}}
  ```

## issue_name_link Macro

Generates a link from an issue's subject. This is useful when you want to create links using the subject instead of issue numbers.

### Basic Syntax

```
{{issue_name_link([project_identifier:]issue_subject[|display_text])}}
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| project_identifier | Optional | Specify when referencing an issue in another project |
| issue_subject | Required | Subject of the target issue (exact match) |
| display_text | Optional | Text to display for the link. Defaults to the issue subject |

### Usage Examples

- Generate a link to an issue with subject "Implement Feature A" in the current project
  ```
  {{issue_name_link(Implement Feature A)}}
  ```

- Display a link to "Bug Fix" with the text "See details"
  ```
  {{issue_name_link(Bug Fix|See details)}}
  ```

- Generate a link to the "Implement Feature B" issue in the `other_project` project
  ```
  {{issue_name_link(other_project:Implement Feature B)}}
  ```

- Generate a link to an issue in another project with display text
  ```
  {{issue_name_link(other_project:Implement Feature B|Link to Feature B)}}
  ```

### Notes

- Issue subjects are searched by exact match
- If multiple issues have the same subject, the link will point to the first one found
- The project identifier can also be specified using the project name

## ref_issues Macro

Displays a list of issues matching specified conditions. You can use custom queries or specify various filters.

### Basic Syntax

```
{{ref_issues([options]..., [columns]...)}}
```

### Options

| Option | Description |
|--------|-------------|
| `-p` | Only issues from the current project |
| `-p=identifier` | Only issues from the specified project |
| `-q=query_name` | Specify custom query by name |
| `-i=query_id` | Specify custom query by ID |
| `-s=keyword` | Search by subject |
| `-d=keyword` | Search by description |
| `-w=keyword` | Search by subject and description |
| `-f:field=value` | Specify filter condition (use `\|` to separate multiple values) |
| `-n=count` | Limit display count (default: 100, max: 1000) |
| `-t` | Display subject as plain text (default is subject attribute) |
| `-t=attribute` | Display specified attribute as plain text |
| `-l` | Display subject as link (default is subject attribute) |
| `-l=attribute` | Display specified attribute as link |
| `-c` | Display count only |
| `-0` | Display nothing if count is 0 |

### Filter Conditions (-f Option)

You can add filter conditions using the `-f:field=value` format.

**Available Fields:**

| Field | Description |
|-------|-------------|
| `status` | Specify by status name |
| `tracker` | Specify by tracker name |
| `assigned_to` | Assignee (login name) |
| `author` | Author (login name) |
| `category` | Category name |
| `version` | Target version name |
| `project` | Project name |
| `cf_number` | Custom field ID |

**Operators:**

You can specify an operator between the field and value.

| Operator | Description |
|----------|-------------|
| `=` | Equal (default) |
| `~` | Contains |
| `!` | Not equal |
| `!~` | Does not contain |
| `o` | Open |
| `c` | Closed |
| `*` | Any value |
| `!*` | No value |

### Special Value References

You can use the following special references in filter values:

| Reference | Description |
|-----------|-------------|
| `[current_user]` | Current user's login name |
| `[current_user_id]` | Current user's ID |
| `[current_project_id]` | Current project's ID |
| `[Ndays_ago]` | Date N days ago (e.g., `[7days_ago]`) |
| `[attribute_name]` | When used in an issue, the value of that issue's attribute |

### Column Specifications

Arguments other than options are interpreted as column names.

**Standard Columns:** `id`, `subject`, `status`, `assigned_to`, `author`, `tracker`, `priority`, `category`, `fixed_version`, `start_date`, `due_date`, `estimated_hours`, `done_ratio`, `created_on`, `updated_on`, etc.

**Short Names:**

| Short Name | Full Name |
|------------|-----------|
| `assigned` | `assigned_to` |
| `updated` | `updated_on` |
| `created` | `created_on` |

**Custom Fields:** Specify using `cf_number` format

### Usage Examples

- Display all issues in the current project
  ```
  {{ref_issues(-p)}}
  ```

- Display results of a custom query named "Open Issues"
  ```
  {{ref_issues(-q=Open Issues)}}
  ```

- Display results of custom query with ID=5
  ```
  {{ref_issues(-i=5)}}
  ```

- Display issues with "New" or "In Progress" status in the current project
  ```
  {{ref_issues(-p, -f:status=New|In Progress)}}
  ```

- Display issues assigned to the current user
  ```
  {{ref_issues(-p, -f:assigned_to=[current_user])}}
  ```

- Display only specified columns
  ```
  {{ref_issues(-p, id, subject, status, assigned_to)}}
  ```

- Display only the issue count for the current project
  ```
  {{ref_issues(-p, -c)}}
  ```

- Display new issues (display nothing if count is 0)
  ```
  {{ref_issues(-p, -f:status=New, -0)}}
  ```

- Limit display to 50 issues
  ```
  {{ref_issues(-p, -n=50)}}
  ```

- Display issue subjects as links inline
  ```
  {{ref_issues(-p, -l)}}
  ```

- Search for issues with "bug" in the subject
  ```
  {{ref_issues(-s=bug)}}
  ```

### Display Count Limit

For server protection, a maximum of 100 issues are displayed when the `-n` option is not specified. A warning message is displayed if there are more than 100 issues.

You can specify up to 1000 issues using the `-n` option.

## Notes

Since these wiki macros can display issue information using arbitrary search conditions, **it is recommended to use them only in environments where only trusted users have access**.

Users with wiki editing permissions may be able to access the following information:
- Issue information from other projects
- Wiki page content from other projects
- Custom field values
