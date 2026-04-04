---
name: new-post
description: Use when the user describes a topic they want to blog about on strebeck.net, or asks to create a new blog post
---

# New Post

Create a new blog post on strebeck.net by inferring metadata from what the user describes, then running the `new-post.sh` script.

## Process

1. **Extract metadata from the user's message.** Determine:
   - **Title**: A concise, descriptive blog post title (title case)
   - **Author**: Default to "Josh Strebeck" unless the user specifies otherwise
   - **Tags**: Lowercase tags relevant to the topic (e.g. `aws, kubernetes, devops`)
   - **Description**: A one-sentence summary of the post

2. **Confirm with the user** before running. Present the inferred values:
   ```
   Title: <title>
   Author: <author>
   Tags: <tags>
   Description: <description>
   ```
   Ask if they want to adjust anything.

3. **Run the script** by piping the values into it. The script reads four lines in order: title, author, tags, description. Use the repo root to locate the script:
   ```bash
   REPO_ROOT=$(git rev-parse --show-toplevel)
   printf '%s\n' '<title>' '<author>' '<tags>' '<description>' | "$REPO_ROOT/scripts/new-post.sh"
   ```

4. **Report the created file path** and remind the user to add content to the post body.

## Notes

- The script auto-generates the date and slug-based filename.
- Tags should be comma-separated, lowercase.
- The script will error if a post with the same slug already exists.
